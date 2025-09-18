// lib/secure/secure_codec.dart
import 'dart:convert';
import 'dart:typed_data';
import 'dart:collection';
import 'package:cryptography/cryptography.dart';
import 'package:crypto/crypto.dart' as crypto;

/// Message type ids (keep 1 for generic JSON payloads)
class MsgType {
  static const int json = 1; // any JSON map (chat, location, etc.)
  static const int ack = 3; // optional acks
  static const int req = 4; // optional requests (e.g., req location)
}

/// Bit flags in header[2]
class MsgFlags {
  static const int frag = 0x01; // payload is a fragment set
}

/// Encrypted wire frame format (all raw bytes):
///   header (12 bytes, AAD) = v(1) | type(1) | flags(1) | hop(1) | senderId(4) | seq(4)
///   ciphertext (N bytes, encrypted payload)
///   tag (16 bytes, AEAD tag)
///
/// If flags.FRAG==1, the PLAINTEXT begins with a 4-byte fragment subheader:
///   frag = seqIdx(1) | total(1) | partLen(2) | partData[..]
///
/// Nonce (12B) is derived, not transmitted: bootSalt(4) | senderId(4) | seq(4)
///
/// Size target: keep total frame <= ~180 bytes to be LoRa-friendly.
class SecureCodec {
  // === Tunables ===
  static const int headerBytes = 12;
  static const int tagBytes = 16;
  static const int fragHdrBytes = 4;
  final int maxFrameBytes; // configurable per deployment

  // AEAD algorithm (use ChaCha20-Poly1305 with 32B key by default)
  final Cipher _aead;
  final SecretKey _key; // 16B for AES-GCM-128 or 32B for ChaCha20-Poly1305
  final Uint8List _kEncBytes; // keep raw kEnc for HMAC
  final int senderId; // 32-bit per-device
  int _seq; // rolling 32-bit counter

  // Reassembly buffers: key = (senderId<<32)|seq
  final _reassembly = HashMap<int, _FragBuf>();
  final Duration _fragTtl = const Duration(seconds: 30);

  /// Build from:
  ///  - kEnc: 32B (from GroupConnectionInfo.kEnc)
  ///  - senderId: 32-bit local id (stable per device)
  ///  - initialSeq: starting sequence (e.g., 0)
  ///  - aeadAlg: 'chacha20' (default) or 'aes-gcm-128'
  SecureCodec({
    required Uint8List kEnc,
    required this.senderId,
    int initialSeq = 0,
    String aeadAlg = 'chacha20',
    int maxFrameBytes = 180,
  })  : _kEncBytes = Uint8List.fromList(kEnc),
        _seq = initialSeq,
        maxFrameBytes = maxFrameBytes,
        _aead = (aeadAlg == 'aes-gcm-128')
            ? AesGcm.with128bits()
            : Chacha20.poly1305Aead(),
        _key = (aeadAlg == 'aes-gcm-128')
            ? SecretKey(kEnc.sublist(0, 16)) // AES-128 uses 16 bytes
            : SecretKey(kEnc); // ChaCha20 uses all 32 bytes

  /// Derive deterministic 4-byte boot salt from group key and sender ID
  static Uint8List _deriveBootSalt4(Uint8List kEnc, int senderId) {
    final bd = ByteData(4)..setUint32(0, senderId, Endian.big);
    final msg = Uint8List.fromList(
      utf8.encode('bootsalt|') + bd.buffer.asUint8List(),
    );
    final mac = crypto.Hmac(crypto.sha256, kEnc).convert(msg).bytes;
    return Uint8List.fromList(mac.take(4).toList());
  }

  // ========= PUBLIC API =========

  /// Encrypt any JSON map as one or more LoRa-friendly frames.
  /// - Minimizes by emitting minified JSON (no whitespace).
  /// - Automatically fragments if needed.
  Future<List<Uint8List>> encryptJson(
    Map<String, dynamic> map, {
    int type = MsgType.json,
    int hop = 0,
  }) async {
    final pt = Uint8List.fromList(
      utf8.encode(jsonEncode(map)),
    ); // minified JSON
    return _encryptPayload(plaintext: pt, type: type, hop: hop);
  }

  /// Try to decrypt a single received frame.
  /// Returns:
  ///  - a complete JSON map (when a full message is reassembled), or
  ///  - null if a) waiting for more fragments, or b) non-JSON type.
  ///
  /// For non-JSON types (acks, etc.), you can hook into [onNonJson] to inspect.
  Future<Map<String, dynamic>?> tryDecryptFrame(
    Uint8List frame, {
    void Function(
      int type,
      int flags,
      int hop,
      int senderId,
      int seq,
      Uint8List plaintext,
    )?
    onNonJson,
    void Function(int received, int total, int senderId, int seq)? onFragProgress,
  }) async {
    final possibleJson = _bytesToJson(frame);
    if (possibleJson != null) return possibleJson;

    final dec = await _decrypt(frame);
    if (dec == null) return null;

    if ((dec.flags & MsgFlags.frag) == 0) {
      // Single-frame message
      if (dec.type == MsgType.json) {
        return _bytesToJson(dec.plaintext);
      } else {
        onNonJson?.call(
          dec.type,
          dec.flags,
          dec.hop,
          dec.senderId,
          dec.seq,
          dec.plaintext,
        );
        return null;
      }
    }

    // Fragmented message
    final key = _keyFor(dec.senderId, dec.seq);
    final fb = _reassembly.putIfAbsent(key, () => _FragBuf());
    final fragInfo = _parseFragHeader(dec.plaintext);
    fb.addPart(fragInfo.seqIdx, fragInfo.total, fragInfo.data);
    onFragProgress?.call(fb.receivedCount, fb.total ?? fragInfo.total, dec.senderId, dec.seq);

    if (fb.isComplete) {
      final whole = fb.assemble();
      _reassembly.remove(key);
      // Whole plaintext belongs to original message type
      if (dec.type == MsgType.json) {
        return _bytesToJson(whole);
      } else {
        onNonJson?.call(
          dec.type,
          dec.flags,
          dec.hop,
          dec.senderId,
          dec.seq,
          whole,
        );
        return null;
      }
    }
    return null; // still waiting for more parts
  }

  /// Remove stale fragment buffers to avoid memory growth.
  void sweepStaleFragments() {
    final now = DateTime.now();
    final stale = <int>[];
    _reassembly.forEach((k, v) {
      if (now.difference(v.lastUpdated) > _fragTtl) {
        stale.add(k);
      }
    });
    for (final k in stale) {
      _reassembly.remove(k);
    }
  }

  // ========= INTERNALS =========

  Future<List<Uint8List>> _encryptPayload({
    required Uint8List plaintext,
    required int type,
    required int hop,
  }) async {
    final maxCipherPerFrame = maxFrameBytes - headerBytes - tagBytes;
    if (plaintext.length <= maxCipherPerFrame) {
      // No fragmentation
      final seq = _nextSeq();
      final header = _buildHeader(
        type: type,
        flags: 0,
        hop: hop,
        senderId: senderId,
        seq: seq,
      );
      final nonce = _buildNonce(senderId, seq);
      final box = await _aead.encrypt(
        plaintext,
        secretKey: _key,
        nonce: nonce,
        aad: header,
      );
      return [_buildFrame(header, box)];
    }

    // Fragmentation
    final perPartPlain = maxCipherPerFrame - fragHdrBytes;
    final totalParts = (plaintext.length / perPartPlain).ceil();
    final seq = _nextSeq();

    final out = <Uint8List>[];
    for (int i = 0; i < totalParts; i++) {
      final start = i * perPartPlain;
      final end = (start + perPartPlain > plaintext.length)
          ? plaintext.length
          : (start + perPartPlain);
      final chunk = plaintext.sublist(start, end);

      final fragPlain = Uint8List(fragHdrBytes + chunk.length);
      final bd = ByteData.sublistView(fragPlain);
      bd.setUint8(0, i); // seqIdx
      bd.setUint8(1, totalParts); // total
      bd.setUint16(2, chunk.length); // partLen
      fragPlain.setAll(fragHdrBytes, chunk);

      final header = _buildHeader(
        type: type,
        flags: MsgFlags.frag,
        hop: hop,
        senderId: senderId,
        seq: seq,
      );
      final nonce = _buildNonce(
        senderId,
        seq,
      ); // same seq for all frags (OK with unique AAD per frame)
      final box = await _aead.encrypt(
        fragPlain,
        secretKey: _key,
        nonce: nonce,
        aad: header,
      );
      out.add(_buildFrame(header, box));
    }
    return out;
  }

  Uint8List _buildHeader({
    required int type,
    required int flags,
    required int hop,
    required int senderId,
    required int seq,
  }) {
    final h = Uint8List(headerBytes);
    final bd = ByteData.sublistView(h);
    bd.setUint8(0, 1); // version
    bd.setUint8(1, type & 0xff);
    bd.setUint8(2, flags & 0xff);
    bd.setUint8(3, hop & 0xff);
    bd.setUint32(4, senderId, Endian.big);
    bd.setUint32(8, seq, Endian.big);
    return h;
  }

  Uint8List _buildNonce(int senderId, int seq) {
    final b = Uint8List(12);
    final bd = ByteData.sublistView(b);

    final salt4 = _deriveBootSalt4(_kEncBytes, senderId); // per-sender
    b.setAll(0, salt4);                    // 0..3 bootSalt(senderId)
    bd.setUint32(4, senderId, Endian.big); // 4..7 senderId
    bd.setUint32(8, seq, Endian.big);      // 8..11 seq
    return b;
  }

  Uint8List _buildFrame(Uint8List header, SecretBox box) {
    final out = Uint8List(
      header.length + box.cipherText.length + box.mac.bytes.length,
    );
    out.setAll(0, header);
    out.setAll(header.length, box.cipherText);
    out.setAll(header.length + box.cipherText.length, box.mac.bytes);
    return out;
  }

  Future<_Dec?> _decrypt(Uint8List frame) async {
    if (frame.length < headerBytes + tagBytes) return null;
    final header = frame.sublist(0, headerBytes);
    final bd = ByteData.sublistView(header);

    final ver = bd.getUint8(0);
    if (ver != 1) return null;

    final type = bd.getUint8(1);
    final flags = bd.getUint8(2);
    final hop = bd.getUint8(3);
    final sid = bd.getUint32(4, Endian.big);
    final seq = bd.getUint32(8, Endian.big);

    final ctLen = frame.length - headerBytes - tagBytes;
    if (ctLen < 0) return null;
    final ct = frame.sublist(headerBytes, headerBytes + ctLen);
    final tag = frame.sublist(headerBytes + ctLen);

    final nonce = _buildNonce(sid, seq);
    final box = SecretBox(ct, nonce: nonce, mac: Mac(tag));
    final pt = await _aead.decrypt(box, secretKey: _key, aad: header);
    return _Dec(type, flags, hop, sid, seq, Uint8List.fromList(pt));
  }

  Map<String, dynamic>? _bytesToJson(Uint8List pt) {
    try {
      return json.decode(utf8.decode(pt)) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  int _nextSeq() {
    _seq = (_seq + 1) & 0xFFFFFFFF;
    if (_seq == 0) _seq = 1; // avoid 0 if you want
    return _seq;
  }

  int _keyFor(int senderId, int seq) =>
      ((senderId & 0xFFFFFFFF) << 32) | (seq & 0xFFFFFFFF);

  _FragInfo _parseFragHeader(Uint8List pt) {
    if (pt.length < fragHdrBytes) throw StateError('fragment header too short');
    final bd = ByteData.sublistView(pt);
    final seqIdx = bd.getUint8(0);
    final total = bd.getUint8(1);
    final partLen = bd.getUint16(2, Endian.big);
    if (fragHdrBytes + partLen > pt.length) {
      throw StateError('fragment lengths invalid');
    }
    final data = pt.sublist(fragHdrBytes, fragHdrBytes + partLen);
    return _FragInfo(seqIdx, total, data);
  }
}

class _Dec {
  final int type, flags, hop, senderId, seq;
  final Uint8List plaintext;
  _Dec(
    this.type,
    this.flags,
    this.hop,
    this.senderId,
    this.seq,
    this.plaintext,
  );
}

class _FragInfo {
  final int seqIdx;
  final int total;
  final Uint8List data;
  _FragInfo(this.seqIdx, this.total, this.data);
}

class _FragBuf {
  int? _total;
  final _parts = <int, Uint8List>{};
  DateTime lastUpdated = DateTime.now();

  void addPart(int idx, int total, Uint8List data) {
    _total ??= total;
    _parts[idx] = data;
    lastUpdated = DateTime.now();
  }

  bool get isComplete => (_total != null) && (_parts.length == _total);

  int? get total => _total;
  int get receivedCount => _parts.length;

  Uint8List assemble() {
    final total = _total!;
    final chunks = List<Uint8List>.generate(
      total,
      (i) => _parts[i]!,
      growable: false,
    );
    final len = chunks.fold<int>(0, (a, b) => a + b.length);
    final out = Uint8List(len);
    int off = 0;
    for (final c in chunks) {
      out.setAll(off, c);
      off += c.length;
    }
    return out;
  }
}
