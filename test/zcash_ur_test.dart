import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:zkool/src/zcash_ur.dart';

void main() {
  test('zcash-pczt matches the Keystone registry vector', () {
    final pczt = _hex(
      '50435a5401000000058ace9cb502b4a1db960c0100c88d06850100000100c49515f62996249233330193b3d553c443a8d45833630192249629f61595c40001ffffffff0f000000a08d061976a914010000000000000000000000000000000000000088ac00000101030000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000005ac80808008858180800880808080080000000000000001a08d061976a914010000000000000000000000000000000000000088ac000001237431487874675859545057324a384265393148585337374d4667783537716b4872764b00000000fbc2f4300c01f0b7820d00e3347c8da4ee614674376cbc45359daa54f9b5493e0000030001ae2935f1dfd8a24aed7c70df7de3a668eb7a49b1319880dde2bbd9031ae5d82f0000',
    );
    const expected =
        'a10159015050435a5401000000058ace9cb502b4a1db960c0100c88d06850100000100c49515f62996249233330193b3d553c443a8d45833630192249629f61595c40001ffffffff0f000000a08d061976a914010000000000000000000000000000000000000088ac00000101030000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000005ac80808008858180800880808080080000000000000001a08d061976a914010000000000000000000000000000000000000088ac000001237431487874675859545057324a384265393148585337374d4667783537716b4872764b00000000fbc2f4300c01f0b7820d00e3347c8da4ee614674376cbc45359daa54f9b5493e0000030001ae2935f1dfd8a24aed7c70df7de3a668eb7a49b1319880dde2bbd9031ae5d82f0000';

    expect(_hexOf(encodeZcashPczt(pczt)), expected);
    expect(decodeZcashPczt(_hex(expected)), pczt);
  });

  test('zcash-accounts matches the Keystone registry vector', () {
    const ufvk =
        'uview1qqqqqqqqqqqqqq8rzd0efkm6ej5n0twzum9czt9kj5y7jxjm9qz3uq9qgpqqqqqqqqqqqqqq9en0hkucteqncqcfqcqcpz4wuwl';
    final accounts = ZcashUrAccounts(
      seedFingerprint: _hex('d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1'),
      accounts: const [
        ZcashUrAccount(ufvk: ufvk, index: 0, name: 'Keystone 1'),
        ZcashUrAccount(ufvk: ufvk, index: 1, name: 'Keystone 2'),
      ],
    );
    const expected =
        'a20150d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d10282d9c033a3017869757669657731717171717171717171717171717138727a643065666b6d36656a356e3074777a756d39637a74396b6a3579376a786a6d39717a33757139716770717171717171717171717171717139656e30686b75637465716e6371636671637163707a347775776c0200036a4b657973746f6e652031d9c033a3017869757669657731717171717171717171717171717138727a643065666b6d36656a356e3074777a756d39637a74396b6a3579376a786a6d39717a33757139716770717171717171717171717171717139656e30686b75637465716e6371636671637163707a347775776c0201036a4b657973746f6e652032';

    expect(_hexOf(encodeZcashAccounts(accounts)), expected);

    final decoded = decodeZcashAccounts(_hex(expected));
    expect(decoded.seedFingerprint, accounts.seedFingerprint);
    expect(decoded.accounts, hasLength(2));
    expect(decoded.accounts[0].ufvk, ufvk);
    expect(decoded.accounts[0].index, 0);
    expect(decoded.accounts[0].name, 'Keystone 1');
    expect(decoded.accounts[1].index, 1);
    expect(decoded.accounts[1].name, 'Keystone 2');
  });

  test('zcash-accounts keeps an account that has no name', () {
    final encoded = encodeZcashAccounts(
      ZcashUrAccounts(
        seedFingerprint: _hex('d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1'),
        accounts: const [ZcashUrAccount(ufvk: 'uview1test', index: 3)],
      ),
    );
    final decoded = decodeZcashAccounts(encoded);
    expect(decoded.accounts.single.ufvk, 'uview1test');
    expect(decoded.accounts.single.index, 3);
    expect(decoded.accounts.single.name, isNull);
  });
}

Uint8List _hex(String value) {
  final bytes = Uint8List(value.length ~/ 2);
  for (var i = 0; i < bytes.length; i++) {
    bytes[i] = int.parse(value.substring(i * 2, i * 2 + 2), radix: 16);
  }
  return bytes;
}

String _hexOf(List<int> bytes) =>
    bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
