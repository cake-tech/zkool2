import 'dart:convert';
import 'dart:typed_data';

/// Keystone UR registry type for a Partially Created Zcash Transaction.
const zcashPcztType = 'zcash-pczt';

/// Keystone UR registry type for the account-linking QR.
const zcashAccountsType = 'zcash-accounts';

/// CBOR tag of `zcash-unified-full-viewing-key` inside `zcash-accounts`.
const zcashUfvkTag = 49203;

/// One unified full viewing key from a Keystone `zcash-accounts` QR.
class ZcashUrAccount {
  const ZcashUrAccount({required this.ufvk, required this.index, this.name});

  final String ufvk;
  final int index;
  final String? name;
}

/// Seed fingerprint plus the accounts Keystone exported.
class ZcashUrAccounts {
  const ZcashUrAccounts({required this.seedFingerprint, required this.accounts});

  final Uint8List seedFingerprint;
  final List<ZcashUrAccount> accounts;
}

/// CBOR map `{1: pczt}` used as the `zcash-pczt` UR payload.
Uint8List encodeZcashPczt(Uint8List pczt) {
  final writer = _CborWriter();
  writer.map(1);
  writer.uint(1);
  writer.byteString(pczt);
  return writer.bytes;
}

Uint8List decodeZcashPczt(Uint8List cbor) {
  final map = _readMap(cbor, 'zcash-pczt');
  final data = map[1];
  if (data is! Uint8List) {
    throw const FormatException('zcash-pczt is missing PCZT bytes');
  }
  return data;
}

/// CBOR map for `zcash-accounts`: fingerprint, then tagged UFVK records.
Uint8List encodeZcashAccounts(ZcashUrAccounts accounts) {
  final writer = _CborWriter();
  writer.map(2);
  writer.uint(1);
  writer.byteString(accounts.seedFingerprint);
  writer.uint(2);
  writer.array(accounts.accounts.length);
  for (final account in accounts.accounts) {
    writer.tag(zcashUfvkTag);
    final fields = account.name == null ? 2 : 3;
    writer.map(fields);
    writer.uint(1);
    writer.text(account.ufvk);
    writer.uint(2);
    writer.uint(account.index);
    final name = account.name;
    if (name != null) {
      writer.uint(3);
      writer.text(name);
    }
  }
  return writer.bytes;
}

ZcashUrAccounts decodeZcashAccounts(Uint8List cbor) {
  final map = _readMap(cbor, 'zcash-accounts');
  final fingerprint = map[1];
  final rawAccounts = map[2];
  if (fingerprint is! Uint8List) {
    throw const FormatException('zcash-accounts is missing a seed fingerprint');
  }
  if (rawAccounts is! List<Object?>) {
    throw const FormatException('zcash-accounts is missing accounts');
  }
  return ZcashUrAccounts(
    seedFingerprint: fingerprint,
    accounts: rawAccounts.map(_decodeAccount).toList(),
  );
}

ZcashUrAccount _decodeAccount(Object? value) {
  if (value is _CborTag) {
    if (value.tag != zcashUfvkTag) {
      throw FormatException('unexpected zcash account tag ${value.tag}');
    }
    value = value.value;
  }
  if (value is! Map<int, Object?>) {
    throw const FormatException('zcash account is not a map');
  }
  final ufvk = value[1];
  final index = value[2];
  final name = value[3];
  if (ufvk is! String || ufvk.isEmpty) {
    throw const FormatException('zcash account is missing a UFVK');
  }
  if (index is! int) {
    throw const FormatException('zcash account is missing an index');
  }
  if (name != null && name is! String) {
    throw const FormatException('zcash account name is not text');
  }
  return ZcashUrAccount(ufvk: ufvk, index: index, name: name as String?);
}

Map<int, Object?> _readMap(Uint8List cbor, String type) {
  final reader = _CborReader(cbor);
  final value = reader.read();
  if (!reader.isDone) {
    throw FormatException('trailing bytes in $type');
  }
  if (value is! Map<int, Object?>) {
    throw FormatException('$type is not a map');
  }
  return value;
}

class _CborTag {
  _CborTag(this.tag, this.value);

  final int tag;
  final Object? value;
}

class _CborWriter {
  final List<int> _bytes = [];

  Uint8List get bytes => Uint8List.fromList(_bytes);

  void uint(int value) => _head(0, value);

  void byteString(List<int> value) {
    _head(2, value.length);
    _bytes.addAll(value);
  }

  void text(String value) {
    final encoded = utf8.encode(value);
    _head(3, encoded.length);
    _bytes.addAll(encoded);
  }

  void array(int length) => _head(4, length);

  void map(int length) => _head(5, length);

  void tag(int value) => _head(6, value);

  void _head(int major, int value) {
    if (value < 0) {
      throw FormatException('negative CBOR integer $value');
    }
    if (value < 24) {
      _bytes.add((major << 5) | value);
    } else if (value <= 0xff) {
      _bytes.add((major << 5) | 24);
      _bytes.add(value);
    } else if (value <= 0xffff) {
      _bytes.add((major << 5) | 25);
      _bytes.add((value >> 8) & 0xff);
      _bytes.add(value & 0xff);
    } else if (value <= 0xffffffff) {
      _bytes.add((major << 5) | 26);
      _bytes.add((value >> 24) & 0xff);
      _bytes.add((value >> 16) & 0xff);
      _bytes.add((value >> 8) & 0xff);
      _bytes.add(value & 0xff);
    } else {
      throw FormatException('CBOR integer is too large: $value');
    }
  }
}

class _CborReader {
  _CborReader(this._bytes);

  final Uint8List _bytes;
  int _index = 0;

  bool get isDone => _index == _bytes.length;

  Object? read() {
    final initial = _byte();
    final major = initial >> 5;
    final additional = initial & 0x1f;
    if (additional == 31) {
      throw const FormatException('indefinite-length CBOR is unsupported');
    }
    final argument = _argument(additional);
    switch (major) {
      case 0:
        return argument;
      case 2:
        return Uint8List.fromList(_take(argument));
      case 3:
        return utf8.decode(_take(argument));
      case 4:
        return List<Object?>.generate(argument, (_) => read());
      case 5:
        final map = <int, Object?>{};
        for (var i = 0; i < argument; i++) {
          final key = read();
          if (key is! int) {
            throw const FormatException('Zcash CBOR map key is not an integer');
          }
          if (map.containsKey(key)) {
            throw FormatException('duplicate Zcash CBOR key $key');
          }
          map[key] = read();
        }
        return map;
      case 6:
        return _CborTag(argument, read());
      default:
        throw FormatException('unsupported CBOR type $major');
    }
  }

  int _byte() {
    if (_index >= _bytes.length) {
      throw const FormatException('truncated CBOR');
    }
    return _bytes[_index++];
  }

  List<int> _take(int length) {
    final end = _index + length;
    if (end > _bytes.length) {
      throw const FormatException('truncated CBOR');
    }
    final slice = _bytes.sublist(_index, end);
    _index = end;
    return slice;
  }

  int _argument(int additional) {
    if (additional < 24) return additional;
    if (additional == 24) return _byte();
    if (additional == 25) return (_byte() << 8) | _byte();
    if (additional == 26) {
      return (_byte() << 24) | (_byte() << 16) | (_byte() << 8) | _byte();
    }
    throw const FormatException('unsupported CBOR integer width');
  }
}
