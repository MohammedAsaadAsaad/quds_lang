import 'dart:typed_data';

/// SHA-256 of [bytes], as a lowercase hex string.
String sha256Hex(List<int> bytes) {
  final digest = _sha256(bytes);
  final out = StringBuffer();
  for (final value in digest) {
    out.write(value.toRadixString(16).padLeft(2, '0'));
  }
  return out.toString();
}

Uint8List _sha256(List<int> message) {
  final hash = Uint32List.fromList(const [
    0x6a09e667,
    0xbb67ae85,
    0x3c6ef372,
    0xa54ff53a,
    0x510e527f,
    0x9b05688c,
    0x1f83d9ab,
    0x5be0cd19,
  ]);
  const k = <int>[
    0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, //
    0x923f82a4, 0xab1c5ed5, 0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3,
    0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174, 0xe49b69c1, 0xefbe4786,
    0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
    0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147,
    0x06ca6351, 0x14292967, 0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13,
    0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85, 0xa2bfe8a1, 0xa81a664b,
    0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
    0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a,
    0x5b9cca4f, 0x682e6ff3, 0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208,
    0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
  ];
  final bitLength = message.length * 8;
  final paddedLength = ((message.length + 9 + 63) ~/ 64) * 64;
  final data = Uint8List(paddedLength);
  data.setRange(0, message.length, message);
  data[message.length] = 0x80;
  final view = ByteData.sublistView(data);
  view.setUint32(paddedLength - 4, bitLength, Endian.big);
  view.setUint32(paddedLength - 8, bitLength ~/ 0x100000000, Endian.big);
  final words = Uint32List(64);
  for (var offset = 0; offset < paddedLength; offset += 64) {
    for (var i = 0; i < 16; i++) {
      words[i] = view.getUint32(offset + i * 4, Endian.big);
    }
    for (var i = 16; i < 64; i++) {
      final s0 = _rotr(words[i - 15], 7) ^
          _rotr(words[i - 15], 18) ^
          (words[i - 15] >> 3);
      final s1 = _rotr(words[i - 2], 17) ^
          _rotr(words[i - 2], 19) ^
          (words[i - 2] >> 10);
      words[i] = _add(words[i - 16], _add(s0, _add(words[i - 7], s1)));
    }
    var a = hash[0];
    var b = hash[1];
    var c = hash[2];
    var d = hash[3];
    var e = hash[4];
    var f = hash[5];
    var g = hash[6];
    var h = hash[7];
    for (var i = 0; i < 64; i++) {
      final s1 = _rotr(e, 6) ^ _rotr(e, 11) ^ _rotr(e, 25);
      final choice = (e & f) ^ (~e & g);
      final temp1 = _add(h, _add(s1, _add(choice, _add(k[i], words[i]))));
      final s0 = _rotr(a, 2) ^ _rotr(a, 13) ^ _rotr(a, 22);
      final majority = (a & b) ^ (a & c) ^ (b & c);
      final temp2 = _add(s0, majority);
      h = g;
      g = f;
      f = e;
      e = _add(d, temp1);
      d = c;
      c = b;
      b = a;
      a = _add(temp1, temp2);
    }
    hash[0] = _add(hash[0], a);
    hash[1] = _add(hash[1], b);
    hash[2] = _add(hash[2], c);
    hash[3] = _add(hash[3], d);
    hash[4] = _add(hash[4], e);
    hash[5] = _add(hash[5], f);
    hash[6] = _add(hash[6], g);
    hash[7] = _add(hash[7], h);
  }
  final out = Uint8List(32);
  final outView = ByteData.sublistView(out);
  for (var i = 0; i < 8; i++) {
    outView.setUint32(i * 4, hash[i], Endian.big);
  }
  return out;
}

int _rotr(int value, int bits) =>
    ((value >> bits) | (value << (32 - bits))) & 0xffffffff;

int _add(int left, int right) => (left + right) & 0xffffffff;
