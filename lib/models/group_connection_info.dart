// group_connection_info.dart
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';

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
  /// Base64 strings from QR (persistable/serializable)
  final String groupSeedB64;
  final String saltB64;

  /// Radio profile from QR
  final int bandwidthHz; // rf.bw (e.g., 125000)
  final int spreadingFactor; // rf.sf (e.g., 7)
  final int centerFrequencyHz; // rf.cf (e.g., 868100000)

  // -------- Derived (computed once) --------
  /// Group AEAD key (use for ChaCha20-Poly1305 32B, or AES-CCM 16B)
  final Uint8List kEnc;

  /// 2-byte LoRa sync word (0..65535)
  final int syncWord;

  GroupConnectionInfo._internal({
    required this.groupSeedB64,
    required this.saltB64,
    required this.bandwidthHz,
    required this.spreadingFactor,
    required this.centerFrequencyHz,
    required this.kEnc,
    required this.syncWord,
  });

  /// Factory: build from QR JSON (does derivations immediately).
  factory GroupConnectionInfo.fromJson(Map<String, dynamic> json) {
    // 1) Parse QR fields
    final String groupSeedB64 = json['groupSeed'] as String;
    final String saltB64 = json['salt'] as String;

    final rf = json['rf'] as Map<String, dynamic>;
    final int bw = (rf['bw'] as num).toInt();
    final int sf = (rf['sf'] as num).toInt();
    final int cf = (rf['cf'] as num).toInt();

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

    return GroupConnectionInfo._internal(
      groupSeedB64: groupSeedB64,
      saltB64: saltB64,
      bandwidthHz: bw,
      spreadingFactor: sf,
      kEnc: kEnc,
      syncWord: syncWord,
      centerFrequencyHz: cf,
    );
  }

  static GroupConnectionInfo fromChannelInfo({
    required String groupSeedB64,
    required String saltB64,
    required int centerFrequencyHz,
    required int bandwidthHz,
    required int spreadingFactor,
  }) {
    return GroupConnectionInfo.fromJson({
      'groupSeed': groupSeedB64,
      'salt': saltB64,
      'rf': {'bw': bandwidthHz, 'sf': spreadingFactor, 'cf': centerFrequencyHz},
    });
  }

  /// Serialize back to the compact QR JSON (invite).
  Map<String, dynamic> toJson() => {
    'groupSeed': groupSeedB64,
    'salt': saltB64,
    'rf': {'bw': bandwidthHz, 'sf': spreadingFactor, 'cf': centerFrequencyHz},
  };

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
}
