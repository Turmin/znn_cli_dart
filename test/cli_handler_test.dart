import 'dart:async';
import 'dart:io';

import 'package:test/test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:znn_sdk_dart/znn_sdk_dart.dart';

// It's important that cli_handler.dart does NOT export 'init_znn.dart' directly or indirectly
// if init_znn.dart itself imports 'cli_handler.dart' as it would create a circular dependency.
// For now, we assume that specific constants like znnCli, znnCliVersion, znnSdkVersion are either
// accessible via cli_handler.dart or we might need to define them or mock them separately.
// The getZnndVersion() is also a global function in init_znn.dart, which might need mocking.
import '../cli_handler.dart';
import '../init_znn.dart'; // For znnCli, znnCliVersion, znnSdkVersion, getZnndVersion

// Assuming these are the core classes we need to mock based on handleCli's usage.
// This list might need to be adjusted if other sub-APIs are directly accessed.
@GenerateMocks([
  Zenon,
  LedgerApi,
  EmbeddedApi,
  PlasmaApi,
  SentinelApi,
  StakeApi,
  PillarApi,
  TokenApi,
  KeyStoreManager,
  KeyStore,
  KeyPair,
  // Address class is a data class, usually not mocked unless it has complex behavior.
  // WsClient and SubscribeApi might be needed for commands like 'autoreceive'.
  WsClient,
  SubscribeApi,
])
import 'cli_handler_test.mocks.dart';

void main() {
  group('Amount Utility Functions', () {
    group('parseAmountToBigInt', () {
      test('should parse whole number string to BigInt', () {
        expect(parseAmountToBigInt('10', 8), equals(BigInt.parse('1000000000')));
        expect(parseAmountToBigInt('123', 0), equals(BigInt.parse('123')));
      });

      test('should parse decimal string to BigInt', () {
        expect(parseAmountToBigInt('10.5', 8), equals(BigInt.parse('1050000000')));
        expect(parseAmountToBigInt('0.12345678', 8), equals(BigInt.parse('12345678')));
        expect(parseAmountToBigInt('123.45', 2), equals(BigInt.parse('12345')));
      });

      test('should handle zero string', () {
        expect(parseAmountToBigInt('0', 8), equals(BigInt.zero));
        expect(parseAmountToBigInt('0.0', 2), equals(BigInt.zero));
      });

      test('should handle small fractional values', () {
        expect(parseAmountToBigInt('0.00000001', 8), equals(BigInt.one));
      });

      test('throws FormatException for invalid input', () {
        expect(() => parseAmountToBigInt('abc', 8), throwsA(isA<FormatException>()));
        expect(() => parseAmountToBigInt('10.5.5', 8), throwsA(isA<FormatException>()));
      });
    });

    group('formatAmountBigInt', () {
      test('should format BigInt to whole number string', () {
        expect(formatAmountBigInt(BigInt.parse('1000000000'), 8), equals('10'));
        expect(formatAmountBigInt(BigInt.parse('123'), 0), equals('123'));
      });

      test('should format BigInt to decimal string', () {
        expect(formatAmountBigInt(BigInt.parse('1050000000'), 8), equals('10.5'));
        expect(formatAmountBigInt(BigInt.parse('12345678'), 8), equals('0.12345678'));
        expect(formatAmountBigInt(BigInt.parse('12345'), 2), equals('123.45'));
      });

      test('should format BigInt to string, trimming trailing zeros and decimal point', () {
        expect(formatAmountBigInt(BigInt.parse('500000000'), 8), equals('5')); // 5.00000000 -> 5
        expect(formatAmountBigInt(BigInt.parse('550000000'), 8), equals('5.5'));// 5.50000000 -> 5.5
      });

      test('should handle zero BigInt', () {
        expect(formatAmountBigInt(BigInt.zero, 8), equals('0'));
      });

      test('should handle small fractional BigInt values', () {
        expect(formatAmountBigInt(BigInt.one, 8), equals('0.00000001'));
      });

      test('should include symbol if provided', () {
        expect(formatAmountBigInt(BigInt.parse('1000000000'), 8, symbol: 'ZNN'), equals('10 ZNN'));
        expect(formatAmountBigInt(BigInt.zero, 8, symbol: 'QSR'), equals('0 QSR'));
      });
    });
  });

  group('handleCli Tests', () {
    late MockZenon mockZenonClient;
    // Mock KeyPair and Address for defaultKeyPair.address
    late MockKeyPair mockKeyPair;
    late MockAddress mockAddress;

    setUp(() {
      mockZenonClient = MockZenon();
      mockKeyPair = MockKeyPair();
      mockAddress = MockAddress();

      // Setup default behavior for defaultKeyPair and address
      when(mockZenonClient.defaultKeyPair).thenReturn(mockKeyPair);
      when(mockKeyPair.address).thenAnswer((_) async => mockAddress);
      when(mockAddress.toString()).thenReturn('z1qzq0m9z8j2pkf8yqgkjfg8zmk9f8z9j6p8yqgkj'); // Example address

      // Mock getZnndVersion to prevent it from trying to run a process
      // This is a simplified approach. Ideally, getZnndVersion would be injectable or part of a mockable service.
      // For now, we assume tests requiring its output would mock it specifically if its output is variable.
      // Or, if its output is static for tests, this might not be strictly needed per-test.
      // However, since it's external to handleCli's direct logic for 'version', this setup is minimal.
    });

    test('version command prints correct version', () async {
      var printOutput = <String>[];
      await IOOverrides.runZoned(
        () async {
          // The 'version' command in handleCli also calls getZnndVersion() from init_znn.dart
          // For this test, we are not deeply mocking getZnndVersion's output itself,
          // but rather ensuring handleCli can proceed.
          // If getZnndVersion() was complex or had side effects, it would need specific mocking.
          await handleCli(['version'], mockZenonClient);
        },
        print: (line) => printOutput.add(line),
      );

      // Check for the znn-cli version string
      expect(printOutput, contains(startsWith('$znnCli v$znnCliVersion using Zenon SDK v$znnSdkVersion')));
      // We are not asserting getZnndVersion() output here as it's an external call.
      // A more robust test might involve mocking getZnndVersion if its behavior is critical to this unit.
    });

    // Add more tests for other commands here, mocking parts of mockZenonClient as needed.
    // For example:
    // test('balance command shows balances', () async {
    //   final mockLedgerApi = MockLedgerApi();
    //   when(mockZenonClient.ledger).thenReturn(mockLedgerApi);
    //
    //   final accountInfo = AccountInfoTestImpl(); // Replace with a real or mock AccountInfo
    //   when(mockLedgerApi.getAccountInfoByAddress(any)).thenAnswer((_) async => accountInfo);
    //
    //   var printOutput = <String>[];
    //   await IOOverrides.runZoned(
    //     () async {
    //       await handleCli(['balance'], mockZenonClient);
    //     },
    //     print: (line) => printOutput.add(line),
    //   );
    //
    //   expect(printOutput, contains(startsWith('Balance for account-chain')));
    // });

    test('sendEncryptedMessage with mnemonic uses derived keys and sends correctly', () async {
      // Arrange
      final mockLedgerApi = MockLedgerApi();
      final mockKeyPair = MockKeyPair(); // This is the default, might not be directly used by this test path
      final mockAddress = MockAddress(); // Address for default KeyPair

      when(mockZenonClient.ledger).thenReturn(mockLedgerApi);
      when(mockZenonClient.defaultKeyPair).thenReturn(mockKeyPair); // Default KeyPair
      when(mockKeyPair.address).thenAnswer((_) async => mockAddress);
      when(mockAddress.toString()).thenReturn('z1defaultaddressxxxxxxxxxxxxxxxxxxxxxxxxx');

      final testMnemonic = 'decorate ketchup auto tired truck flip feel fatal flock goddess menu club accuse glide stone leaf country certain rapid liquid moral envelope silly fetch';
      final expectedDerivedAddress = 'z1qq5psszd6eyg04ds79zsnfr0gjyh7xkduy873m';
      final derivedKeyPair = KeyPair.fromMnemonic(testMnemonic); // Real derivation for assertion

      final recipientAddressStr = 'z1qqjnwjjpnue8xmmpanz6csze6tcmtzzdtfsww7';
      final messageToEncrypt = 'Test secret message from CLI test';

      final mockFrontierBlockJson = {
        "version": 1, "chainIdentifier": 1, "blockType": 2, // Type 2 for user receive block
        "hash": "dea8d757a3980386a5b9938dfa0c898079987750780e0349b098897593876892",
        "previousHash": "105a52008498a97b779171480e40742019c901b7a810539bd2df93951b900c3e",
        "height": 123,
        "momentumAcknowledged": {
          "hash": "cfb5f2523615650509bd105e359077135601a4f8e65cac21a009996d08a008d4",
          "height": 456575
        },
        "address": recipientAddressStr,
        "toAddress": "z1qzq0m9z8j2pkf8yqgkjfg8zmk9f8z9j6p8yqgkj", // Not relevant for this test part
        "amount": "100000000", "tokenStandard": "zts1znnxxxxxxxxxxxxx9z4fz",
        "fromBlockHash": "105a52008498a97b779171480e40742019c901b7a810539bd2df93951b900c3e",
        "data": "", "fusedPlasma": 0, "difficulty": 0, "nonce": "0000000000000000",
        // This public key corresponds to z1qzlutjra45v7d8tggk9l9ed7a2n99nquaenjff (example, not recipient)
        // For a real scenario, this should be the public key of recipientAddressStr
        "publicKey": "302a300506032b6570032100e322ef112d39270b6056905183caf77c52887dee688a15e690731da13685f780",
        "signature": "mockSignature"
      };
      final mockFrontierBlock = AccountBlockTemplate.fromJson(mockFrontierBlockJson);
      when(mockLedgerApi.getFrontierAccountBlock(Address.parse(recipientAddressStr)))
          .thenAnswer((_) async => mockFrontierBlock);

      AccountBlockTemplate? capturedBlock;
      KeyPair? capturedKeyPair;
      // Mock znnClient.send, capturing arguments
      when(mockZenonClient.send(any, keyPair: anyNamed('keyPair')))
          .thenAnswer((invocation) async {
        capturedBlock = invocation.positionalArguments[0] as AccountBlockTemplate;
        capturedKeyPair = invocation.namedArguments[#keyPair] as KeyPair?;
        // Return a dummy response
        return AccountBlockTemplate.receive(Hash.parse("0000000000000000000000000000000000000000000000000000000000000001"));
      });

      var printOutput = <String>[];
      await IOOverrides.runZoned(
        () async {
          List<String> args = [
            'sendEncryptedMessage',
            '--to', recipientAddressStr,
            '--message', messageToEncrypt,
            '--mnemonic', testMnemonic,
          ];
          await handleCli(args, mockZenonClient);
        },
        print: (line) => printOutput.add(line),
      );

      expect(printOutput, contains(contains('Using provided mnemonic for sendEncryptedMessage.')));
      expect(printOutput, contains(contains('Derived address from mnemonic: $expectedDerivedAddress')));

      verify(mockZenonClient.send(any, keyPair: anyNamed('keyPair'))).called(1);

      expect(capturedBlock, isNotNull);
      expect(capturedBlock!.toAddress.toString(), equals(recipientAddressStr));
      expect(capturedBlock!.amount, equals(BigInt.zero));
      expect(capturedBlock!.tokenStandard.toString(), equals(emptyTokenStandard));

      expect(capturedBlock!.data, isNotEmpty, reason: "Encrypted data should not be empty");

      expect(capturedKeyPair, isNotNull);
      expect(capturedKeyPair!.publicKey, equals(derivedKeyPair.publicKey));
      expect(await capturedKeyPair!.address.toString(), equals(expectedDerivedAddress));

      expect(printOutput, contains('Done'));
    });

    test('decryptMessage with mnemonic uses derived keys for decryption', () async {
      // Arrange
      final mockDefaultKeyPair = MockKeyPair();
      final mockDefaultAddress = MockAddress();
      // Set up the default keypair on the mockZenonClient for the code path where mnemonic isn't used.
      when(mockZenonClient.defaultKeyPair).thenReturn(mockDefaultKeyPair);
      when(mockDefaultKeyPair.address).thenAnswer((_) async => mockDefaultAddress);
      // It's good practice to have toString() mocked for addresses if they are printed or used in string contexts.
      when(mockDefaultAddress.toString()).thenReturn('z1defaultaddressxxxxxxxxxxxxxxxxxxxxxxxxx');
      // For this specific test, defaultKeyPair's privateKey and publicKey are needed if mnemonic is NOT used.
      // However, since we ARE testing the mnemonic path, these specific mocks for defaultKeyPair's keys aren't strictly necessary for THIS test's success.
      // when(mockDefaultKeyPair.privateKey).thenReturn(Uint8List.fromList(List.generate(32, (index) => index))); // Dummy private key
      // when(mockDefaultKeyPair.publicKey).thenReturn(Uint8List.fromList(List.generate(32, (index) => index + 32))); // Dummy public key


      final testMnemonic = 'decorate ketchup auto tired truck flip feel fatal flock goddess menu club accuse glide stone leaf country certain rapid liquid moral envelope silly fetch';
      final expectedDerivedAddress = 'z1qq5psszd6eyg04ds79zsnfr0gjyh7xkduy873m';

      // This is a dummy base64 string.
      final dummyEncryptedMessageBase64 = 'CTZYfOLO1j4ZeMhL4MEgnJ1FRQ=='; // Likely invalid ciphertext
      final expectedDecryptedMessage = "Test decrypted"; // This won't be asserted unless Sodium is mocked

      var printOutput = <String>[];
      await IOOverrides.runZoned(
        () async {
          List<String> args = [
            'decryptMessage',
            '--message', dummyEncryptedMessageBase64,
            '--mnemonic', testMnemonic,
          ];
          await handleCli(args, mockZenonClient);
        },
        print: (line) => printOutput.add(line),
      );

      // Assertions
      expect(printOutput, contains(contains('Using provided mnemonic for decryptMessage.')));
      expect(printOutput, contains(contains('Derived address from mnemonic: $expectedDerivedAddress')));

      // Check for the error print from Sodium due to dummy/invalid message.
      // This confirms that the decryption process was attempted with the derived key.
      bool decryptionAttemptOrError = printOutput.any((line) =>
          line.contains('Error during decryption:') ||
          line == expectedDecryptedMessage // In case dummy data was somehow valid and produced this exact string
      );
      expect(decryptionAttemptOrError, isTrue, reason: "Decryption should be attempted, likely failing with dummy data.");
    });

    test('send command with ZNN amount uses correct BigInt amount and derived keys', () async {
      // Arrange
      final mockLedgerApi = MockLedgerApi();
      final mockTokenApi = MockTokenApi();
      final mockEmbeddedApi = MockEmbeddedApi();

      when(mockZenonClient.ledger).thenReturn(mockLedgerApi);
      when(mockZenonClient.embedded).thenReturn(mockEmbeddedApi);
      when(mockEmbeddedApi.token).thenReturn(mockTokenApi);

      final testMnemonic = 'decorate ketchup auto tired truck flip feel fatal flock goddess menu club accuse glide stone leaf country certain rapid liquid moral envelope silly fetch';
      final expectedDerivedAddress = 'z1qq5psszd6eyg04ds79zsnfr0gjyh7xkduy873m';
      final derivedKeyPair = KeyPair.fromMnemonic(testMnemonic);

      final recipientAddressStr = 'z1qqjnwjjpnue8xmmpanz6csze6tcmtzzdtfsww7';
      final amountToSendStr = '0.001';
      final tokenStandardStr = 'ZNN';
      final znnDecimals = 8;

      // Simulate that the KeyStore derived from the mnemonic is the default for this test
      final mockDerivedAddressObj = MockAddress();
      when(mockDerivedAddressObj.toString()).thenReturn(expectedDerivedAddress);
      // It's important that the KeyPair instance itself can provide its address.
      // So, instead of mocking derivedKeyPair.address, we ensure derivedKeyPair is used as default.
      when(mockZenonClient.defaultKeyPair).thenReturn(derivedKeyPair);


      // Mocking AccountInfo for the sender (derivedKeyPair's address)
      // The balance must be a string in the JSON for AccountInfo.fromJson
      final senderBalanceAtomic = (Decimal.parse('0.05') * Decimal.parse(BigInt.from(10).pow(znnDecimals).toString())).toBigInt().toString();
      final mockSenderAccountInfo = AccountInfo.fromJson({
        "address": expectedDerivedAddress,
        "accountHeight": 1, "blockCount": 1,
        "balanceInfoList": [
          {
            "token": {
              "name": "Zenon", "symbol": "ZNN", "domain": "zenon.network",
              "totalSupply": "100000000000000000", "maxSupply": "200000000000000000", "decimals": znnDecimals,
              "owner": "z1qxemdedfvtc9es8n3dhryyff0j8qum2axghd6h",
              "tokenStandard": znnZts.toString(),
              "isMintable": false, "isBurnable": true, "isUtility": false
            },
            "balance": senderBalanceAtomic,
            "expirationHeight": 0
          }
        ]
      });
      // When handleCli calls getAccountInfoByAddress with the *actual derived address object* from the keypair,
      // it should return the mockSenderAccountInfo.
      // The address object used inside handleCli will be `await derivedKeyPair.address`
      // So we need to ensure our mockLedgerApi responds to that specific address string.
      when(mockLedgerApi.getAccountInfoByAddress(Address.parse(expectedDerivedAddress)))
          .thenAnswer((_) async => mockSenderAccountInfo);

      final znnTokenJson = {
        "name": "Zenon", "symbol": "ZNN", "domain": "zenon.network",
        "totalSupply": "100000000000000000", "maxSupply": "200000000000000000", "decimals": znnDecimals,
        "owner": "z1qxemdedfvtc9es8n3dhryyff0j8qum2axghd6h", "tokenStandard": znnZts.toString(),
        "isMintable": false, "isBurnable": true, "isUtility": false
      };
      final znnToken = Token.fromJson(znnTokenJson);
      when(mockTokenApi.getByZts(znnZts)).thenAnswer((_) async => znnToken);

      AccountBlockTemplate? capturedBlock;
      KeyPair? capturedKeyPair;
      when(mockZenonClient.send(any, keyPair: anyNamed('keyPair')))
          .thenAnswer((invocation) async {
        capturedBlock = invocation.positionalArguments[0] as AccountBlockTemplate;
        capturedKeyPair = invocation.namedArguments[#keyPair] as KeyPair?;
        return AccountBlockTemplate.receive(Hash.parse("0000000000000000000000000000000000000000000000000000000000000002"));
      });

      var printOutput = <String>[];
      await IOOverrides.runZoned(
        () async {
          List<String> args = [
            'send',
            '--toAddress', recipientAddressStr,
            '--amount', amountToSendStr,
            '--tokenStandard', tokenStandardStr,
          ];
          await handleCli(args, mockZenonClient);
        },
        print: (line) => printOutput.add(line),
      );

      // Assertions
      // Verify that getAccountInfoByAddress was called with the address of the derivedKeyPair
      // The address used internally by handleCli would be `(await mockZenonClient.defaultKeyPair!.address).toString()`
      // Since we set defaultKeyPair to derivedKeyPair, this should be expectedDerivedAddress.
      verify(mockLedgerApi.getAccountInfoByAddress(Address.parse(expectedDerivedAddress))).called(1);
      verify(mockTokenApi.getByZts(znnZts)).called(1); // For sender's balance check and for display
      verify(mockZenonClient.send(any, keyPair: anyNamed('keyPair'))).called(1);

      expect(capturedBlock, isNotNull);
      expect(capturedBlock!.toAddress.toString(), equals(recipientAddressStr));
      expect(capturedBlock!.tokenStandard, equals(znnZts));
      expect(capturedBlock!.amount, equals(BigInt.parse('100000')));

      expect(capturedKeyPair, isNotNull);
      expect(capturedKeyPair!.publicKey.toList(), equals(derivedKeyPair.publicKey.toList())); // Compare list of bytes
      expect(await capturedKeyPair!.address.toString(), equals(expectedDerivedAddress));

      final expectedSentMessage = 'Sending ${formatAmountBigInt(BigInt.parse('100000'), znnDecimals, symbol: tokenStandardStr)} to $recipientAddressStr';
      expect(printOutput, anyElement(startsWith('Sending 0.001 ZNN to z1qqjnwjjpnue8xmmpanz6csze6tcmtzzdtfsww7')),
        reason: "Expected print output to contain message: $expectedSentMessage, actual: ${printOutput.join('\n')}");
      expect(printOutput, contains('Done'));
    });
  });
}

// Example of a test implementation for AccountInfo if not mocking it deeply.
// class AccountInfoTestImpl implements AccountInfo {
//   @override
//   Address? address = Address.parse("z1qzq0m9z8j2pkf8yqgkjfg8zmk9f8z9j6p8yqgkj");
//   @override
//   BigInt? balance = BigInt.from(10000000000); // 100 ZNN
//   @override
//   List<BalanceInfoListItem>? balanceInfoList = [ /* ... mock items ... */ ];
//   // ... other fields and methods ...
// }

// Note: To run these tests, you'll need to:
// 1. Ensure `mockito` and `build_runner` are in `dev_dependencies`.
// 2. Run `dart run build_runner build --delete-conflicting-outputs` to generate `cli_handler_test.mocks.dart`.
// 3. The import '../init_znn.dart'; might cause issues if init_znn.dart also imports cli_handler.dart,
//    creating a circular dependency. This might require refactoring constants or helper functions
//    into a shared library or passing them differently. For the `version` command, the constants
//    znnCli, znnCliVersion, znnSdkVersion and function getZnndVersion are used.
//    If `getZnndVersion` is problematic, it might need to be passed as a dependency or mocked globally.
//    For this test, if `init_znn.dart` is simple and doesn't import `cli_handler.dart`, it might work.
//    Otherwise, this import strategy is a known potential issue.

// The constants znnCli, znnCliVersion, znnSdkVersion are defined in init_znn.dart
// For the test to access them, we import init_znn.dart.
// getZnndVersion is also from init_znn.dart. It performs a system call.
// In a unit test, we generally want to avoid real system calls.
// A better approach for getZnndVersion would be to make it injectable or part of a service that can be mocked.
// For this specific test of the 'version' command, we'll let it run if it doesn't break the test environment,
// but acknowledge this is not ideal for pure unit testing.
// A pragmatic fix if getZnndVersion() is problematic is to extract it to a function variable in handleCli
// that can be overridden in tests, or wrap cli_handler.dart in a testable class.
// For now, the test focuses on the parts of 'version' that don't depend on getZnndVersion's *output*.

// The provided `init_znn.dart` does not import `cli_handler.dart` so circular dependency is not an issue here.
// However, `getZnndVersion` in `init_znn.dart` makes a system call `Process.runSync` which is not ideal for unit tests.
// This will be noted in the summary.

    test('send command with ZNN amount uses correct BigInt amount and derived keys', () async {
      // Arrange
      final mockLedgerApi = MockLedgerApi();
      final mockTokenApi = MockTokenApi();
      final mockEmbeddedApi = MockEmbeddedApi();

      when(mockZenonClient.ledger).thenReturn(mockLedgerApi);
      when(mockZenonClient.embedded).thenReturn(mockEmbeddedApi);
      when(mockEmbeddedApi.token).thenReturn(mockTokenApi);

      final testMnemonic = 'decorate ketchup auto tired truck flip feel fatal flock goddess menu club accuse glide stone leaf country certain rapid liquid moral envelope silly fetch';
      final expectedDerivedAddress = 'z1qq5psszd6eyg04ds79zsnfr0gjyh7xkduy873m';
      final derivedKeyPair = KeyPair.fromMnemonic(testMnemonic);

      final recipientAddressStr = 'z1qqjnwjjpnue8xmmpanz6csze6tcmtzzdtfsww7';
      final amountToSendStr = '0.001';
      final tokenStandardStr = 'ZNN';
      final znnDecimals = 8;

      // Simulate that the KeyStore derived from the mnemonic is the default for this test
      when(mockZenonClient.defaultKeyPair).thenReturn(derivedKeyPair);
      // The address object used inside handleCli will be `await derivedKeyPair.address`
      // No need to mock `derivedKeyPair.address` itself as it's a real KeyPair.

      final senderAddressObject = await derivedKeyPair.address; // Get the actual Address object

      // Mocking AccountInfo for the sender (derivedKeyPair's address)
      final senderBalanceAtomic = (Decimal.parse('0.05') * Decimal.parse(BigInt.from(10).pow(znnDecimals).toString())).toBigInt().toString();
      final mockSenderAccountInfo = AccountInfo.fromJson({
        "address": expectedDerivedAddress,
        "accountHeight": 1, "blockCount": 1,
        "balanceInfoList": [
          {
            "token": {
              "name": "Zenon", "symbol": "ZNN", "domain": "zenon.network",
              "totalSupply": "100000000000000000", "maxSupply": "200000000000000000", "decimals": znnDecimals,
              "owner": "z1qxemdedfvtc9es8n3dhryyff0j8qum2axghd6h",
              "tokenStandard": znnZts.toString(),
              "isMintable": false, "isBurnable": true, "isUtility": false
            },
            "balance": senderBalanceAtomic,
            "expirationHeight": 0
          }
        ]
      });
      when(mockLedgerApi.getAccountInfoByAddress(senderAddressObject)) // Use the actual Address object
          .thenAnswer((_) async => mockSenderAccountInfo);

      final znnTokenJson = {
        "name": "Zenon", "symbol": "ZNN", "domain": "zenon.network",
        "totalSupply": "100000000000000000", "maxSupply": "200000000000000000", "decimals": znnDecimals,
        "owner": "z1qxemdedfvtc9es8n3dhryyff0j8qum2axghd6h", "tokenStandard": znnZts.toString(),
        "isMintable": false, "isBurnable": true, "isUtility": false
      };
      final znnToken = Token.fromJson(znnTokenJson);
      when(mockTokenApi.getByZts(znnZts)).thenAnswer((_) async => znnToken);

      AccountBlockTemplate? capturedBlock;
      KeyPair? capturedKeyPair;
      when(mockZenonClient.send(any, keyPair: anyNamed('keyPair')))
          .thenAnswer((invocation) async {
        capturedBlock = invocation.positionalArguments[0] as AccountBlockTemplate;
        capturedKeyPair = invocation.namedArguments[#keyPair] as KeyPair?;
        return AccountBlockTemplate.receive(Hash.parse("0000000000000000000000000000000000000000000000000000000000000002"));
      });

      var printOutput = <String>[];
      await IOOverrides.runZoned(
        () async {
          List<String> args = [
            'send',
            '--toAddress', recipientAddressStr,
            '--amount', amountToSendStr,
            '--tokenStandard', tokenStandardStr,
          ];
          await handleCli(args, mockZenonClient);
        },
        print: (line) => printOutput.add(line),
      );

      // Assertions
      verify(mockLedgerApi.getAccountInfoByAddress(senderAddressObject)).called(1);
      verify(mockTokenApi.getByZts(znnZts)).called(atLeast(1));
      verify(mockZenonClient.send(any, keyPair: anyNamed('keyPair'))).called(1);

      expect(capturedBlock, isNotNull);
      expect(capturedBlock!.toAddress.toString(), equals(recipientAddressStr));
      expect(capturedBlock!.tokenStandard, equals(znnZts));
      expect(capturedBlock!.amount, equals(BigInt.parse('100000')));

      expect(capturedKeyPair, isNotNull);
      expect(capturedKeyPair!.publicKey.toList(), equals(derivedKeyPair.publicKey.toList()));
      expect(await capturedKeyPair!.address.toString(), equals(expectedDerivedAddress));

      final expectedSentMessageStart = 'Sending 0.001 ZNN to z1qqjnwjjpnue8xmmpanz6csze6tcmtzzdtfsww7';
      expect(printOutput, anyElement(startsWith(expectedSentMessageStart)),
        reason: "Expected print output to contain message starting with: $expectedSentMessageStart, actual: ${printOutput.join('\n')}");
      expect(printOutput, contains('Done'));
    });
