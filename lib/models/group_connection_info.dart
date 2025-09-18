// group_connection_info.dart
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';

/// Describes the channel plan layout for EU868 125 kHz, 200 kHz spacing, 12 slots.
/// Start = 863.1 MHz, Step = 200 kHz, Count = 12  → indices 0..11
class _PlanSpec {
  final int startHz;
  final int stepHz;
  final int count;
  const _PlanSpec(this.startHz, this.stepHz, this.count);

  static _PlanSpec fromPlanLabel(String plan) {
    switch (plan) {
      case 'EU868-125k-200kstep-12':
        return _PlanSpec(863100000, 200000, 12);
      default:
        throw ArgumentError('Unknown plan label: $plan');
    }
  }

  int indexToFreqHz(int index) {
    if (index < 0 || index >= count) {
      throw RangeError('Channel index $index out of range 0..${count - 1}');
    }
    return startHz + index * stepHz;
  }

  List<int> allFreqsHz() => List<int>.generate(count, indexToFreqHz);
}

/// Simple deterministic PRNG (xorshift32) for stable shuffles derived from seed.
class _XorShift32 {
  int _state;
  _XorShift32(int seed) : _state = seed == 0 ? 0xA3C59AC3 : seed;
  int nextUint32() {
    int x = _state;
    x ^= (x << 13) & 0xFFFFFFFF;
    x ^= (x >> 17);
    x ^= (x << 5) & 0xFFFFFFFF;
    _state = x & 0xFFFFFFFF;
    return _state;
  }

  int nextInt(int upperExclusive) {
    // Map 32-bit to range [0, upperExclusive)
    final v = nextUint32() & 0x7FFFFFFF;
    return upperExclusive == 0 ? 0 : v % upperExclusive;
  }
}

/// Minimal HKDF-SHA256 (RFC 5869)
class _Hkdf {
  static Uint8List extract(Uint8List salt, Uint8List ikm) {
    final h = Hmac(sha256, salt);
    final prk = h.convert(ikm).bytes;
    return Uint8List.fromList(prk);
  }

  static Uint8List expand(Uint8List prk, List<int> info, int len) {
    final h = Hmac(sha256, prk);
    final blocks = <int>[];
    Uint8List previous = Uint8List(0);
    var remaining = len;
    var counter = 1;
    while (remaining > 0) {
      final input = BytesBuilder()
        ..add(previous)
        ..add(info)
        ..add([counter]);
      previous = Uint8List.fromList(h.convert(input.toBytes()).bytes);
      final take = min(remaining, previous.length);
      blocks.addAll(previous.take(take));
      remaining -= take;
      counter++;
    }
    return Uint8List.fromList(blocks);
  }

  /// Convenience: HKDF-Extract+Expand with ASCII info label.
  static Uint8List derive(
    Uint8List salt,
    Uint8List ikm, {
    required String infoLabel,
    required int length,
  }) {
    final prk = extract(salt, ikm);
    return expand(prk, utf8.encode(infoLabel), length);
  }
}

/// Holds both the invite payload (what's in the QR) and all derived params.
/// - Store seeds as Base64 in JSON, but expose bytes + derived fields for use.
/// - Derivation is deterministic: same (groupSeed,salt,rf,chan) → same outputs.
class GroupConnectionInfo {
  /// Protocol version from QR (`proto`)
  final int protocolVersion;

  /// Base64 strings from QR (persistable/serializable)
  final String groupSeedB64;
  final String saltB64;

  /// Radio profile from QR
  final int bandwidthHz; // rf.bw (e.g., 125000)
  final int spreadingFactor; // rf.sf (e.g., 7)
  final String planLabel; // rf.plan (e.g., 'EU868-125k-200kstep-12')

  /// Primary channel index from QR (chan.primaryIndex)
  final int primaryIndex;

  // -------- Derived (computed once) --------
  /// Group AEAD key (use for ChaCha20-Poly1305 32B, or AES-CCM 16B)
  final Uint8List kEnc;

  /// 2-byte LoRa sync word (0..65535)
  final int syncWord;

  /// 2-byte app-level fast filter placed in your packet header
  final int netId;

  /// Deterministic permutation of channel indices for this group
  final List<int> channelOrder;

  /// Backups = next 2 indices following the primary within channelOrder
  final List<int> backupIndices;

  GroupConnectionInfo._internal({
    required this.protocolVersion,
    required this.groupSeedB64,
    required this.saltB64,
    required this.bandwidthHz,
    required this.spreadingFactor,
    required this.planLabel,
    required this.primaryIndex,
    required this.kEnc,
    required this.syncWord,
    required this.netId,
    required this.channelOrder,
    required this.backupIndices,
  });

  /// Factory: build from QR JSON (does derivations immediately).
  factory GroupConnectionInfo.fromJson(Map<String, dynamic> json) {
    // 1) Parse QR fields
    final int proto = (json['proto'] as num).toInt();
    final String groupSeedB64 = json['groupSeed'] as String;
    final String saltB64 = json['salt'] as String;

    final rf = json['rf'] as Map<String, dynamic>;
    final int bw = (rf['bw'] as num).toInt();
    final int sf = (rf['sf'] as num).toInt();
    final String plan = rf['plan'] as String;

    final chan = json['chan'] as Map<String, dynamic>;
    final int primary = (chan['primaryIndex'] as num).toInt();

    // 2) Decode seeds
    final Uint8List seedBytes = base64Decode(groupSeedB64);
    final Uint8List saltBytes = base64Decode(saltB64);

    if (seedBytes.length < 16) {
      throw ArgumentError('groupSeed must be at least 16 bytes');
    }
    if (saltBytes.length < 8) {
      throw ArgumentError('salt must be at least 8 bytes');
    }

    // 3) Derive a root key from (seed + salt)
    final Uint8List root = _Hkdf.derive(
      saltBytes,
      seedBytes,
      infoLabel: 'pair-root',
      length: 32,
    );

    // 4) Derive sub-keys/fields (all deterministic)
    final Uint8List kEnc = _Hkdf.derive(
      root,
      Uint8List.fromList([]),
      infoLabel: 'kenc',
      length: 32, // 32B for ChaCha20-Poly1305 (or trim to 16B for AES-CCM)
    );

    final Uint8List syncBytes = _Hkdf.derive(
      root,
      Uint8List.fromList([]),
      infoLabel: 'sync_word',
      length: 2,
    );
    final int syncWord =
        (syncBytes[0] << 8) | syncBytes[1]; // big-endian → 0..65535

    final Uint8List netBytes = _Hkdf.derive(
      root,
      Uint8List.fromList([]),
      infoLabel: 'net_id',
      length: 2,
    );
    final int netId = (netBytes[0] << 8) | netBytes[1];

    // 5) Build channel plan, then derive a deterministic permutation
    final planSpec = _PlanSpec.fromPlanLabel(plan);
    final List<int> order = _deriveChannelOrder(root, planSpec.count);

    // Ensure primaryIndex exists in the plan
    if (primary < 0 || primary >= planSpec.count) {
      throw RangeError(
        'primaryIndex $primary out of range 0..${planSpec.count - 1}',
      );
    }

    // Compute backups: next 2 indices in the permutation AFTER the primary
    final int pos = order.indexOf(primary);
    // If primary isn't in the order somehow, fallback to natural order
    final int p = (pos >= 0) ? pos : primary;
    final int a = order[(p + 1) % order.length];
    final int b = order[(p + 2) % order.length];
    final List<int> backups = [a, b];

    return GroupConnectionInfo._internal(
      protocolVersion: proto,
      groupSeedB64: groupSeedB64,
      saltB64: saltB64,
      bandwidthHz: bw,
      spreadingFactor: sf,
      planLabel: plan,
      primaryIndex: primary,
      kEnc: kEnc,
      syncWord: syncWord,
      netId: netId,
      channelOrder: order,
      backupIndices: backups,
    );
  }

  /// Serialize back to the compact QR JSON (invite).
  Map<String, dynamic> toJson() => {
        'proto': protocolVersion,
        'groupSeed': groupSeedB64,
        'salt': saltB64,
        'rf': {
          'bw': bandwidthHz,
          'sf': spreadingFactor,
          'plan': planLabel,
        },
        'chan': {
          'primaryIndex': primaryIndex,
        },
      };

  /// Returns the frequency (Hz) for a given channel index per the plan.
  int freqHzForIndex(int index) =>
      _PlanSpec.fromPlanLabel(planLabel).indexToFreqHz(index);

  /// Returns (primary frequency Hz).
  int get primaryFreqHz => freqHzForIndex(primaryIndex);

  /// Returns the backup frequencies (Hz) corresponding to [backupIndices].
  List<int> get backupFreqsHz =>
      backupIndices.map((i) => freqHzForIndex(i)).toList(growable: false);

  /// All frequencies (Hz) in this plan (natural order, not the permutation).
  List<int> get allPlanFreqsHz =>
      _PlanSpec.fromPlanLabel(planLabel).allFreqsHz();

  /// A short key-id/fingerprint to verify both sides derived the same K_enc.
  String get keyIdHex {
    final digest = sha256.convert(kEnc).bytes;
    // first 8 bytes → 16 hex chars
    final first8 = digest.take(8).toList(growable: false);
    final sb = StringBuffer();
    for (final b in first8) {
      sb.write(b.toRadixString(16).padLeft(2, '0'));
    }
    return sb.toString();
  }

  /// Utility to create a secure 32-bit memberId (unique per device).
  static int generateMemberId() {
    final r = Random.secure();
    int v = 0;
    for (int i = 0; i < 4; i++) {
      v = (v << 8) | r.nextInt(256);
    }
    return v & 0xFFFFFFFF;
  }

  /// Utility to generate a fresh bootSalt (4 random bytes).
  static Uint8List generateBootSalt() {
    final r = Random.secure();
    final out = Uint8List(4);
    for (int i = 0; i < 4; i++) {
      out[i] = r.nextInt(256);
    }
    return out;
  }

  /// Build a provisioning record for the Heltec firmware (SET_GROUP).
  Map<String, dynamic> toProvisioningRecord({
    required int memberId,          // unique per device
    int seqInit = 0,                // starting sequence number
    Uint8List? bootSalt,            // 4B random salt (if null, auto-generate)
    String aeadAlg = 'chacha20',    // or 'aes-gcm-128'
  }) {
    final bs = bootSalt ?? generateBootSalt();
    return {
      'cmd': 'SET_GROUP',
      'freqHz': primaryFreqHz,
      'bw': bandwidthHz,
      'sf': spreadingFactor,
      'syncWord': syncWord,
      'netId': netId,
      'aead': {
        'alg': aeadAlg,
        'key': base64Encode(kEnc),
        'nonceMode': 'memberId|seq|bootSalt',
      },
      'memberId': memberId & 0xFFFFFFFF,
      'seqInit': seqInit,
      'bootSalt': base64Encode(bs),
      'backups': backupIndices,
    };
  }

  /// Deterministically permute channel indices 0..count-1 from the root key.
  static List<int> _deriveChannelOrder(Uint8List root, int count) {
    final order = List<int>.generate(count, (i) => i);
    // Derive a 4-byte shuffle seed from HKDF(root, "channel")
    final seedBytes = _Hkdf.derive(
      root,
      Uint8List(0),
      infoLabel: 'channel',
      length: 4,
    );
    final seed = (seedBytes[0] << 24) |
        (seedBytes[1] << 16) |
        (seedBytes[2] << 8) |
        (seedBytes[3]);
    final rng = _XorShift32(seed & 0xFFFFFFFF);

    // Fisher-Yates shuffle
    for (int i = order.length - 1; i > 0; i--) {
      final j = rng.nextInt(i + 1);
      final tmp = order[i];
      order[i] = order[j];
      order[j] = tmp;
    }
    return order;
  }

  
}
