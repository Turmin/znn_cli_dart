import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:bip39/bip39.dart' as bip39;
import 'package:args/args.dart';
import 'package:dcli/dcli.dart';
import 'package:path/path.dart' as path;
import 'package:znn_sdk_dart/znn_sdk_dart.dart';
import 'package:decimal/decimal.dart';
import 'package:decimal/helpers.dart';

import 'init_znn.dart';
import 'libsodium/sodium.dart';

// Helper function to parse amount string to BigInt
BigInt parseAmountToBigInt(String amountStr, int decimals) {
  final exponent = BigInt.from(10).pow(decimals);
  final decimalValue = Decimal.parse(amountStr);
  final scaledValue = decimalValue * Decimal.parse(exponent.toString());
  return scaledValue.toBigInt();
}

// Helper function to format BigInt amount to string
String formatAmountBigInt(BigInt amount, int decimals, {String symbol = ''}) {
  if (amount == BigInt.zero && symbol.isEmpty) return '0';
  if (amount == BigInt.zero) return '0 ${symbol}'.trim();

  final exponent = BigInt.from(10).pow(decimals);
  final value = Decimal.fromBigInt(amount) / Decimal.fromBigInt(exponent);

  // Format to string with specified decimals, then remove trailing zeros and decimal point if it's effectively a whole number.
  String formatted = value.toStringAsFixed(decimals);
  if (formatted.contains('.')) {
    formatted = formatted.replaceAll(RegExp(r'0*$'), ''); // Remove trailing zeros
    if (formatted.endsWith('.')) {
      formatted = formatted.substring(0, formatted.length - 1); // Remove trailing decimal point
    }
  }
  return '${formatted} ${symbol}'.trim();
}

// Commenting out the old formatAmount function as it will be replaced
/*
String formatAmount(int amount, int decimals) {
  double value = amount / pow(10, decimals);
  if (value == 0) return '0';
  return value.toStringAsFixed(decimals).replaceAll(RegExp(r'\.0*$'), '');
}
*/

Future<int> main(List<String> args) async {
  return initZnn(args, handleCli);
}

// Modified to accept Zenon instance
Future<void> handleCli(List<String> args, Zenon znnClient) async {
  // final Zenon znnClient = Zenon(); // Instance is now passed as a parameter
  Address? address = (await znnClient.defaultKeyPair?.address);

  final parser = ArgParser(allowTrailingOptions: true);

  // Top-level commands
  parser.addCommand('version');

  final sendParser = ArgParser();
  sendParser.addOption('toAddress', help: 'Recipient address', mandatory: true);
  sendParser.addOption('amount', help: 'Amount to send', mandatory: true);
  sendParser.addOption('tokenStandard', help: 'Token standard (ZNN, QSR, or ZTS ID)', mandatory: true);
  sendParser.addOption('message', help: 'Optional message');
  parser.addCommand('send', sendParser);

  final receiveParser = ArgParser();
  receiveParser.addOption('hash', help: 'Hash of the send block', mandatory: true);
  parser.addCommand('receive', receiveParser);

  parser.addCommand('receiveAll');
  parser.addCommand('autoreceive');
  parser.addCommand('unreceived');
  parser.addCommand('unconfirmed');
  parser.addCommand('balance');
  parser.addCommand('frontierMomentum');

  final plasmaFuseParser = ArgParser();
  plasmaFuseParser.addOption('toAddress', help: 'Beneficiary address', mandatory: true);
  plasmaFuseParser.addOption('amount', help: 'Amount of QSR to fuse', mandatory: true);
  parser.addCommand('plasma.fuse', plasmaFuseParser);

  parser.addCommand('plasma.get');

  final plasmaListParser = ArgParser();
  plasmaListParser.addOption('pageIndex', defaultsTo: '0');
  plasmaListParser.addOption('pageSize', defaultsTo: '25');
  parser.addCommand('plasma.list', plasmaListParser);

  final plasmaCancelParser = ArgParser();
  plasmaCancelParser.addOption('id', help: 'ID of the fusion entry to cancel', mandatory: true);
  parser.addCommand('plasma.cancel', plasmaCancelParser);

  parser.addCommand('sentinel.list');
  parser.addCommand('sentinel.register');
  parser.addCommand('sentinel.revoke');
  parser.addCommand('sentinel.collect');
  parser.addCommand('sentinel.withdrawQsr');

  final stakeListParser = ArgParser();
  stakeListParser.addOption('pageIndex', defaultsTo: '0');
  stakeListParser.addOption('pageSize', defaultsTo: '25');
  parser.addCommand('stake.list', stakeListParser);

  final stakeRegisterParser = ArgParser();
  stakeRegisterParser.addOption('amount', help: 'Amount of ZNN to stake', mandatory: true);
  stakeRegisterParser.addOption('duration', help: 'Duration in months (1-12)', mandatory: true);
  parser.addCommand('stake.register', stakeRegisterParser);

  final stakeRevokeParser = ArgParser();
  stakeRevokeParser.addOption('id', help: 'ID of the stake entry to revoke', mandatory: true);
  parser.addCommand('stake.revoke', stakeRevokeParser);

  parser.addCommand('stake.collect');

  parser.addCommand('pillar.list');

  final pillarRegisterParser = ArgParser();
  pillarRegisterParser.addOption('name', mandatory: true);
  pillarRegisterParser.addOption('producerAddress', mandatory: true);
  pillarRegisterParser.addOption('rewardAddress', mandatory: true);
  pillarRegisterParser.addOption('giveBlockRewardPercentage', mandatory: true);
  pillarRegisterParser.addOption('giveDelegateRewardPercentage', mandatory: true);
  parser.addCommand('pillar.register', pillarRegisterParser);

  parser.addCommand('pillar.collect');

  final pillarRevokeParser = ArgParser();
  pillarRevokeParser.addOption('name', help: 'Name of the Pillar to revoke', mandatory: true);
  parser.addCommand('pillar.revoke', pillarRevokeParser);

  final pillarDelegateParser = ArgParser();
  pillarDelegateParser.addOption('name', help: 'Name of the Pillar to delegate to', mandatory: true);
  parser.addCommand('pillar.delegate', pillarDelegateParser);

  parser.addCommand('pillar.undelegate');
  parser.addCommand('pillar.withdrawQsr');

  final tokenListParser = ArgParser();
  tokenListParser.addOption('pageIndex', defaultsTo: '0');
  tokenListParser.addOption('pageSize', defaultsTo: '25');
  parser.addCommand('token.list', tokenListParser);

  final tokenGetByStandardParser = ArgParser();
  tokenGetByStandardParser.addOption('tokenStandard', mandatory: true);
  parser.addCommand('token.getByStandard', tokenGetByStandardParser);

  final tokenGetByOwnerParser = ArgParser();
  tokenGetByOwnerParser.addOption('ownerAddress', mandatory: true);
  parser.addCommand('token.getByOwner', tokenGetByOwnerParser);

  final tokenIssueParser = ArgParser();
  tokenIssueParser.addOption('name', mandatory: true);
  tokenIssueParser.addOption('symbol', mandatory: true);
  tokenIssueParser.addOption('domain', mandatory: true);
  tokenIssueParser.addOption('totalSupply', mandatory: true);
  tokenIssueParser.addOption('maxSupply', mandatory: true);
  tokenIssueParser.addOption('decimals', mandatory: true);
  tokenIssueParser.addOption('isMintable', mandatory: true);
  tokenIssueParser.addOption('isBurnable', mandatory: true);
  tokenIssueParser.addOption('isUtility', mandatory: true);
  parser.addCommand('token.issue', tokenIssueParser);

  final tokenMintParser = ArgParser();
  tokenMintParser.addOption('tokenStandard', mandatory: true);
  tokenMintParser.addOption('amount', mandatory: true);
  tokenMintParser.addOption('receiveAddress', mandatory: true);
  parser.addCommand('token.mint', tokenMintParser);

  final tokenBurnParser = ArgParser();
  tokenBurnParser.addOption('tokenStandard', mandatory: true);
  tokenBurnParser.addOption('amount', mandatory: true);
  parser.addCommand('token.burn', tokenBurnParser);

  final tokenTransferOwnershipParser = ArgParser();
  tokenTransferOwnershipParser.addOption('tokenStandard', mandatory: true);
  tokenTransferOwnershipParser.addOption('newOwnerAddress', mandatory: true);
  parser.addCommand('token.transferOwnership', tokenTransferOwnershipParser);

  final tokenDisableMintParser = ArgParser();
  tokenDisableMintParser.addOption('tokenStandard', mandatory: true);
  parser.addCommand('token.disableMint', tokenDisableMintParser);

  final walletCreateNewParser = ArgParser();
  walletCreateNewParser.addOption('passphrase', mandatory: true);
  walletCreateNewParser.addOption('keyStoreName');
  parser.addCommand('wallet.createNew', walletCreateNewParser);

  final walletCreateFromMnemonicParser = ArgParser();
  walletCreateFromMnemonicParser.addOption('mnemonic', mandatory: true);
  walletCreateFromMnemonicParser.addOption('passphrase', mandatory: true);
  walletCreateFromMnemonicParser.addOption('keyStoreName');
  parser.addCommand('wallet.createFromMnemonic', walletCreateFromMnemonicParser);

  parser.addCommand('wallet.dumpMnemonic');

  final walletExportParser = ArgParser();
  walletExportParser.addOption('filePath', mandatory: true);
  parser.addCommand('wallet.export', walletExportParser);

  parser.addCommand('wallet.list');

  final walletDeriveAddressesParser = ArgParser();
  walletDeriveAddressesParser.addOption('left', mandatory: true);
  walletDeriveAddressesParser.addOption('right', mandatory: true);
  parser.addCommand('wallet.deriveAddresses', walletDeriveAddressesParser);

  final sendEncryptedMessageParser = ArgParser();
  sendEncryptedMessageParser.addOption('mnemonic',
      help: 'The mnemonic to use for deriving the key.');
  sendEncryptedMessageParser.addOption('to',
      abbr: 't', help: 'The recipient address.', mandatory: true);
  sendEncryptedMessageParser.addOption('message',
      abbr: 'm', help: 'The message content.', mandatory: true);
  parser.addCommand('sendEncryptedMessage', sendEncryptedMessageParser);

  final decryptMessageParser = ArgParser();
  decryptMessageParser.addOption('mnemonic',
      help: 'The mnemonic to use for deriving the key.');
  decryptMessageParser.addOption('message',
      abbr: 'm', help: 'The encrypted message content.', mandatory: true);
  parser.addCommand('decryptMessage', decryptMessageParser);

  ArgResults results;
  try {
    results = parser.parse(args);
    if (results.command == null && args.isNotEmpty) {
      // If no command was parsed but args were provided, it's an unknown command
      print(red('Error: Unknown command `${args[0]}`'));
      help();
      return;
    } else if (results.command == null && args.isEmpty) {
      // No command, print help
      help();
      return;
    }
  } on ArgParserException catch (e) { // Catch specific ArgParserException
    print(red('Error: ${e.message}'));
    // Try to find which command it might have been for more specific help
    if (args.isNotEmpty && parser.commands.containsKey(args[0])) {
       print('\nUsage for command `${args[0]}`:');
       print(parser.commands[args[0]]!.usage);
    } else {
       help(); // General help
    }
    return;
  } catch (e) {
    print(red('Error: ${e.toString()}'));
    help();
    return;
  }

  final commandResults = results.command!;

  switch (results.command?.name) {
    case 'version':
      print('$znnCli v$znnCliVersion using Zenon SDK v$znnSdkVersion');
      print(getZnndVersion());
      break;

    case 'send':
      Address newAddress = Address.parse(commandResults['toAddress']);
      late BigInt amount; // Changed to BigInt
      TokenStandard tokenStandard;
      String tsArg = commandResults['tokenStandard'];
      if (tsArg.toLowerCase() == 'znn') {
        tokenStandard = znnZts;
      } else if (tsArg.toLowerCase() == 'qsr') {
        tokenStandard = qsrZts;
      } else {
        tokenStandard = TokenStandard.parse(tsArg);
      }

      AccountInfo info =
          await znnClient.ledger.getAccountInfoByAddress(address!);
      bool ok = true;
      bool found = false;
      for (BalanceInfoListItem entry in info.balanceInfoList!) {
        if (entry.token!.tokenStandard.toString() == tokenStandard.toString()) {
          // Use the new parseAmountToBigInt helper
          amount = parseAmountToBigInt(commandResults['amount'], entry.token!.decimals);
          // Assuming entry.balance is already BigInt from the SDK
          if (entry.balance! < amount) {
            print(
                '${red("Error!")} You only have ${formatAmountBigInt(entry.balance!, entry.token!.decimals, symbol: entry.token!.symbol)} tokens');
            ok = false;
            break;
          }
          found = true;
        }
      }

      if (!ok) break;
      if (!found) {
        // Use formatAmountBigInt for displaying zero balance
        // Need to fetch token details to get decimals if not found in balance list.
        // This logic path implies the token standard was valid but account has 0 of it.
        Token? tempToken = await znnClient.embedded.token.getByZts(tokenStandard);
        int decimalsForError = tempToken?.decimals ?? 0; // Default to 0 if token not found (should ideally not happen if tsArg is valid)
        print(
            '${red("Error!")} You only have ${formatAmountBigInt(BigInt.zero, decimalsForError, symbol: tokenStandard.toString())} tokens');
        break;
      }
      Token? token = await znnClient.embedded.token.getByZts(tokenStandard);
      // Ensure amount is BigInt for AccountBlockTemplate.send
      var block = AccountBlockTemplate.send(newAddress, tokenStandard, amount);

      String? messageArg = commandResults['message'];
      if (messageArg != null) {
        block.data = AsciiEncoder().convert(messageArg);
        print(
            'Sending ${formatAmountBigInt(amount, token!.decimals, symbol: tsArg)} to ${commandResults['toAddress']} with a message "$messageArg"');
      } else {
        print(
            'Sending ${formatAmountBigInt(amount, token!.decimals, symbol: tsArg)} to ${commandResults['toAddress']}');
      }

      await znnClient.send(block);
      print('Done');
      break;

    case 'receive':
      Hash sendBlockHash = Hash.parse(commandResults['hash']);
      print('Please wait ...');
      await znnClient.send(AccountBlockTemplate.receive(sendBlockHash));
      print('Done');
      break;

    case 'receiveAll':
      var unreceived = (await znnClient.ledger
          .getUnreceivedBlocksByAddress(address!, pageIndex: 0, pageSize: 5));
      if (unreceived.count == 0) {
        print('Nothing to receive');
        break;
      } else {
        if (unreceived.more!) {
          print(
              'You have ${red("more")} than ${green(unreceived.count.toString())} transaction(s) to receive');
        } else {
          print(
              'You have ${green(unreceived.count.toString())} transaction(s) to receive');
        }
      }

      print('Please wait ...');
      while (unreceived.count! > 0) {
        for (var block in unreceived.list!) {
          await znnClient.send(AccountBlockTemplate.receive(block.hash));
        }
        unreceived = (await znnClient.ledger
            .getUnreceivedBlocksByAddress(address, pageIndex: 0, pageSize: 5));
      }
      print('Done');
      break;

    case 'autoreceive':
      znnClient.wsClient
          .addOnConnectionEstablishedCallback((broadcaster) async {
        print('Subscribing for account-block events ...');
        await znnClient.subscribe.toAllAccountBlocks();
        print('Subscribed successfully!');

        broadcaster.listen((json) async {
          if (json!["method"] == "ledger.subscription") {
            for (var i = 0; i < json["params"]["result"].length; i += 1) {
              var tx = json["params"]["result"][i];
              if (tx["toAddress"] != address.toString()) {
                continue;
              }
              var hash = tx["hash"];
              print("receiving transaction with hash $hash");
              var template = await znnClient
                  .send(AccountBlockTemplate.receive(Hash.parse(hash)));
              print(
                  "successfully received $hash. Receive-block-hash ${template.hash}");
              await Future.delayed(Duration(seconds: 1));
            }
          }
        });
      });

      for (;;) {
        await Future.delayed(Duration(seconds: 1));
      }

    case 'unreceived':
      var unreceived = await znnClient.ledger
          .getUnreceivedBlocksByAddress(address!, pageIndex: 0, pageSize: 5);

      if (unreceived.count == 0) {
        print('Nothing to receive');
      } else {
        if (unreceived.more!) {
          print(
              'You have ${red("more")} than ${green(unreceived.count.toString())} transaction(s) to receive');
        } else {
          print(
              'You have ${green(unreceived.count.toString())} transaction(s) to receive');
        }
        print('Showing the first ${unreceived.list!.length}');
      }

      for (var block in unreceived.list!) {
        // Assuming block.amount is BigInt and block.token.decimals is int
        print(
            'Unreceived ${formatAmountBigInt(block.amount, block.token!.decimals, symbol: block.token!.symbol)} from ${block.address.toString()}. Use the hash ${block.hash} to receive');
      }
      break;

    case 'unconfirmed':
      var unconfirmed = await znnClient.ledger
          .getUnconfirmedBlocksByAddress(address!, pageIndex: 0, pageSize: 5);

      if (unconfirmed.count == 0) {
        print('No unconfirmed transactions');
      } else {
        print(
            'You have ${green(unconfirmed.count.toString())} unconfirmed transaction(s)');
        print('Showing the first ${unconfirmed.list!.length}');
      }

      var encoder = JsonEncoder.withIndent("     ");
      for (var block in unconfirmed.list!) {
        print(encoder.convert(block.toJson()));
      }
      break;

    case 'balance':
      AccountInfo info =
          await znnClient.ledger.getAccountInfoByAddress(address!);
      print(
          'Balance for account-chain ${info.address!.toString()} having height ${info.blockCount}');
      if (info.balanceInfoList!.isEmpty) {
        print('  No coins or tokens at address ${address.toString()}');
      }
      for (BalanceInfoListItem entry in info.balanceInfoList!) {
        // Use the new formatAmountBigInt helper
        // Assuming entry.balance is BigInt and entry.token.decimals is int
        print(
            '  ${formatAmountBigInt(entry.balance!, entry.token!.decimals, symbol: entry.token!.symbol)} '
            '${entry.token!.domain} ${entry.token!.tokenStandard.toString()}');
      }
      break;

    case 'frontierMomentum':
      Momentum currentFrontierMomentum =
          await znnClient.ledger.getFrontierMomentum();
      print('Momentum height: ${currentFrontierMomentum.height.toString()}');
      print('Momentum hash: ${currentFrontierMomentum.hash.toString()}');
      print(
          'Momentum previousHash: ${currentFrontierMomentum.previousHash.toString()}');
      print(
          'Momentum timestamp: ${currentFrontierMomentum.timestamp.toString()}');
      break;

    case 'plasma.fuse':
      Address beneficiary = Address.parse(commandResults['toAddress']);
      // Assuming commandResults['amount'] for plasma.fuse is expected in QSR units.
      BigInt amount = parseAmountToBigInt(commandResults['amount'], qsrDecimals);

      // Assuming fuseMinQsrAmount is in atomic units (BigInt)
      if (amount < fuseMinQsrAmount) { // fuseMinQsrAmount should be BigInt
        print(
            '${red('Invalid amount')}: ${formatAmountBigInt(amount, qsrDecimals, symbol: blue('QSR'))}. Minimum staking amount is ${formatAmountBigInt(fuseMinQsrAmount, qsrDecimals, symbol: blue('QSR'))}');
        break;
      }
      // This check might need adjustment based on how users are expected to input QSR for fuse.
      // If users are expected to provide whole QSR units, this check is fine.
      // The original code `(double.parse(args[2]) * oneQsr).round()` converted user input to atomic int.
      // parseAmountToBigInt handles this.

      print(
          'Fusing ${formatAmountBigInt(amount, qsrDecimals, symbol: blue('QSR'))} to ${commandResults['toAddress']}');
      // SDK expects BigInt for amount here
      await znnClient.send(znnClient.embedded.plasma.fuse(beneficiary, amount));
      print('Done');
      break;

    case 'plasma.get':
      PlasmaInfo plasmaInfo = await znnClient.embedded.plasma.get(address!);
      // Assuming plasmaInfo.qsrAmount is BigInt
      print(
          '${green(address.toString())} has ${plasmaInfo.currentPlasma} / ${plasmaInfo.maxPlasma}'
          ' plasma with ${formatAmountBigInt(plasmaInfo.qsrAmount, qsrDecimals, symbol: blue('QSR'))} fused.');
      break;

    case 'plasma.list':
      int pageIndex = int.parse(commandResults['pageIndex']);
      int pageSize = int.parse(commandResults['pageSize']);
      FusionEntryList fusionEntryList = (await znnClient.embedded.plasma
          .getEntriesByAddress(address!,
              pageIndex: pageIndex, pageSize: pageSize));

      if (fusionEntryList.count > 0) {
        // Assuming fusionEntryList.qsrAmount is BigInt
        print(
            'Fusing ${formatAmountBigInt(fusionEntryList.qsrAmount, qsrDecimals, symbol: blue('QSR'))} for Plasma in ${fusionEntryList.count} entries');
      } else {
        print('No Plasma fusion entries found');
      }

      for (FusionEntry entry in fusionEntryList.list) {
        // Assuming entry.qsrAmount is BigInt
        print(
            '  ${formatAmountBigInt(entry.qsrAmount, qsrDecimals, symbol: blue('QSR'))} for ${entry.beneficiary.toString()}');
        print(
            'Can be canceled at momentum height: ${entry.expirationHeight}. Use id ${entry.id} to cancel');
      }
      break;

    case 'plasma.cancel':
      Hash id = Hash.parse(commandResults['id']);
      int pageIndexPg = 0;
      bool foundPg = false;
      bool gotErrorPg = false;

      FusionEntryList fusions =
          await znnClient.embedded.plasma.getEntriesByAddress(address!);
      while (fusions.list.isNotEmpty) {
        var index = fusions.list.indexWhere((entry) => entry.id == id);
        if (index != -1) {
          foundPg = true;
          if (fusions.list[index].expirationHeight >
              (await znnClient.ledger.getFrontierMomentum()).height) {
            print('${red('Error!')} Fuse entry can not be cancelled yet');
            gotErrorPg = true;
          }
          break;
        }
        pageIndexPg++;
        fusions = await znnClient.embedded.plasma
            .getEntriesByAddress(address, pageIndex: pageIndexPg);
      }

      if (!foundPg) {
        print('${red('Error!')} Fuse entry was not found');
        break;
      }
      if (gotErrorPg) {
        break;
      }
      print('Canceling Plasma fuse entry with id ${commandResults['id']}');
      await znnClient.send(znnClient.embedded.plasma.cancel(id));
      print('Done');
      break;

    case 'sentinel.list':
      SentinelInfoList sentinels =
          (await znnClient.embedded.sentinel.getAllActive());
      bool oneSn = false;
      for (SentinelInfo entry in sentinels.list) {
        if (entry.owner.toString() == address!.toString()) {
          if (entry.isRevocable) {
            print(
                'Revocation window will close in ${formatDuration(entry.revokeCooldown)}');
          } else {
            print(
                'Revocation window will open in ${formatDuration(entry.revokeCooldown)}');
          }
          oneSn = true;
        }
      }
      if (!oneSn) {
        print('No Sentinel registered at address ${address!.toString()}');
      }
      break;

    case 'sentinel.register':
      AccountInfo accountInfo =
          await znnClient.ledger.getAccountInfoByAddress(address!);
      var depositedQsrSn =
          await znnClient.embedded.sentinel.getDepositedQsr(address); // This is BigInt
      print('You have ${formatAmountBigInt(depositedQsrSn ?? BigInt.zero, qsrDecimals, symbol: blue('QSR'))} deposited for the Sentinel');
      // sentinelRegisterZnnAmount and sentinelRegisterQsrAmount are BigInt from SDK constants
      if (accountInfo.znn()! < sentinelRegisterZnnAmount ||
          accountInfo.qsr()! < sentinelRegisterQsrAmount) {
        print('Cannot register Sentinel with address ${address.toString()}');
        print(
            'Required ${formatAmountBigInt(sentinelRegisterZnnAmount, znnDecimals, symbol: green('ZNN'))} and ${formatAmountBigInt(sentinelRegisterQsrAmount, qsrDecimals, symbol: blue('QSR'))}');
        print(
            'Available ${formatAmountBigInt(accountInfo.znn()!, znnDecimals, symbol: green('ZNN'))} and ${formatAmountBigInt(accountInfo.qsr()!, qsrDecimals, symbol: blue('QSR'))}');
        break;
      }

      if (depositedQsrSn == null || depositedQsrSn < sentinelRegisterQsrAmount) {
        BigInt amountToDeposit = sentinelRegisterQsrAmount - (depositedQsrSn ?? BigInt.zero);
        await znnClient.send(znnClient.embedded.sentinel.depositQsr(amountToDeposit));
      }
      await znnClient.send(znnClient.embedded.sentinel.register());
      print('Done');
      print(
          'Check after 2 momentums if the Sentinel was successfully registered using ${green('sentinel.list')} command');
      break;

    case 'sentinel.revoke':
      SentinelInfo? entrySr = await znnClient.embedded.sentinel
          .getByOwner(address!)
          .catchError((e) {
        if (e.toString().contains('data non existent')) {
          return null;
        } else {
          print("Error: ${e.toString()}");
        }
      });

      if (entrySr == null) {
        print('No Sentinel found for address ${address.toString()}');
        break;
      }

      if (entrySr.isRevocable == false) {
        print(
            'Cannot revoke Sentinel. Revocation window will open in ${formatDuration(entrySr.revokeCooldown)}');
        break;
      }

      await znnClient.send(znnClient.embedded.sentinel.revoke());
      print('Done');
      print(
          'Use ${green('receiveAll')} to collect back the locked amount of ${green('ZNN')} and ${blue('QSR')}');
      break;

    case 'sentinel.collect':
      await znnClient.send(znnClient.embedded.sentinel.collectReward());
      print('Done');
      print(
          'Use ${green('receiveAll')} to collect your Sentinel reward(s) after 1 momentum');
      break;

    case 'sentinel.withdrawQsr':
      BigInt? depositedQsrSw =
          await znnClient.embedded.sentinel.getDepositedQsr(address!);
      if (depositedQsrSw == null || depositedQsrSw == BigInt.zero) {
        print('No deposited ${blue('QSR')} to withdraw');
        break;
      }
      print(
          'Withdrawing ${formatAmountBigInt(depositedQsrSw, qsrDecimals, symbol: blue('QSR'))} ...');
      await znnClient.send(znnClient.embedded.sentinel.withdrawQsr());
      print('Done');
      break;

    case 'stake.list':
      int pageIndexSl = int.parse(commandResults['pageIndex']);
      int pageSizeSl = int.parse(commandResults['pageSize']);
      final currentTimeSl =
          (DateTime.now().millisecondsSinceEpoch / 1000).round();
      StakeList stakeList = await znnClient.embedded.stake.getEntriesByAddress(
          address!,
          pageIndex: pageIndexSl,
          pageSize: pageSizeSl);

      if (stakeList.count > 0) {
        print(
            'Showing ${stakeList.list.length} out of a total of ${stakeList.count} staking entries');
      } else {
        print('No staking entries found');
      }

      for (StakeEntry entry in stakeList.list) {
        print(
            'Stake id ${entry.id.toString()} with amount ${formatAmountBigInt(entry.amount, znnDecimals, symbol: green('ZNN'))}');
        if (entry.expirationTimestamp > currentTimeSl) {
          print(
              '    Can be revoked in ${formatDuration(entry.expirationTimestamp - currentTimeSl)}');
        } else {
          print('    ${green('Can be revoked now')}');
        }
      }
      break;

    case 'stake.register':
      // Use parseAmountToBigInt for amount
      final BigInt amountSr = parseAmountToBigInt(commandResults['amount'], znnDecimals);
      final int durationSr = int.parse(commandResults['duration']);

      if (durationSr < 1 || durationSr > 12) {
        print(
            '${red('Invalid duration')}: ($durationSr) $stakeUnitDurationName. It must be between 1 and 12');
        break;
      }
      // Assuming stakeMinZnnAmount is BigInt
      if (amountSr < stakeMinZnnAmount) {
        print(
            '${red('Invalid amount')}: ${formatAmountBigInt(amountSr, znnDecimals, symbol: green('ZNN'))}. Minimum staking amount is ${formatAmountBigInt(stakeMinZnnAmount, znnDecimals, symbol: green('ZNN'))}');
        break;
      }
      AccountInfo balanceSr =
          await znnClient.ledger.getAccountInfoByAddress(address!);
      // Assuming balanceSr.znn() is BigInt
      if (balanceSr.znn()! < amountSr) {
        print(red('Not enough ZNN to stake'));
        break;
      }

      print(
          'Staking ${formatAmountBigInt(amountSr, znnDecimals, symbol: green('ZNN'))} for $durationSr $stakeUnitDurationName(s)');
      // SDK expects BigInt for stake amount
      await znnClient.send(
          znnClient.embedded.stake.stake(stakeTimeUnitSec * durationSr, amountSr));
      print('Done');
      break;

    case 'stake.revoke':
      Hash hashSr = Hash.parse(commandResults['id']);
      final currentTimeSrv =
          (DateTime.now().millisecondsSinceEpoch / 1000).round();
      int pageIndexSrv = 0;
      bool oneSrv = false;
      bool gotErrorSrv = false;

      StakeList entriesSrv = await znnClient.embedded.stake
          .getEntriesByAddress(address!, pageIndex: pageIndexSrv);
      while (entriesSrv.list.isNotEmpty) {
        for (StakeEntry entry in entriesSrv.list) {
          if (entry.id.toString() == hashSr.toString()) {
            if (entry.expirationTimestamp > currentTimeSrv) {
              print(
                  '${red('Cannot revoke!')} Try again in ${formatDuration(entry.expirationTimestamp - currentTimeSrv)}');
              gotErrorSrv = true;
            }
            oneSrv = true;
          }
        }
        pageIndexSrv++;
        entriesSrv = await znnClient.embedded.stake
            .getEntriesByAddress(address, pageIndex: pageIndexSrv);
      }

      if (gotErrorSrv) {
        break;
      } else if (!oneSrv) {
        print(
            '${red('Error!')} No stake entry found with id ${hashSr.toString()}');
        break;
      }

      await znnClient.send(znnClient.embedded.stake.cancel(hashSr));
      print('Done');
      print(
          'Use ${green('receiveAll')} to collect your stake amount and uncollected reward(s) after 2 momentums');
      break;

    case 'stake.collect':
      await znnClient.send(znnClient.embedded.stake.collectReward());
      print('Done');
      print(
          'Use ${green('receiveAll')} to collect your stake reward(s) after 1 momentum');
      break;

    case 'pillar.list':
      PillarInfoList pillarList = (await znnClient.embedded.pillar.getAll());
      for (PillarInfo pillar in pillarList.list) {
        print(
            '#${pillar.rank + 1} Pillar ${green(pillar.name)} has a delegated weight of ${formatAmountBigInt(pillar.weight, znnDecimals, symbol: green('ZNN'))}');
        print('    Producer address ${pillar.producerAddress}');
        print(
            '    Momentums ${pillar.currentStats.producedMomentums} / expected ${pillar.currentStats.expectedMomentums}');
      }
      break;

    case 'pillar.register':
      String namePr = commandResults['name'];
      Address producerAddressPr = Address.parse(commandResults['producerAddress']);
      Address rewardAddressPr = Address.parse(commandResults['rewardAddress']);
      int giveBlockRewardPercentagePr = int.parse(commandResults['giveBlockRewardPercentage']);
      int giveDelegateRewardPercentagePr = int.parse(commandResults['giveDelegateRewardPercentage']);

      AccountInfo balancePr =
          await znnClient.ledger.getAccountInfoByAddress(address!);
      BigInt? qsrAmountPr = // Ensure this is BigInt?
          (await znnClient.embedded.pillar.getQsrRegistrationCost());
      BigInt? depositedQsrPr = // Ensure this is BigInt?
          await znnClient.embedded.pillar.getDepositedQsr(address);

      if (qsrAmountPr == null) {
        print(red('Error: Could not retrieve QSR registration cost for Pillar.'));
        break;
      }

      if ((balancePr.znn()! < pillarRegisterZnnAmount || balancePr.qsr()! < qsrAmountPr) &&
          (depositedQsrPr == null || qsrAmountPr > depositedQsrPr)) {
        print('Cannot register Pillar with address ${address.toString()}');
        print(
            'Required ${formatAmountBigInt(pillarRegisterZnnAmount, znnDecimals, symbol: green('ZNN'))} and ${formatAmountBigInt(qsrAmountPr, qsrDecimals, symbol: blue('QSR'))}');
        print(
            'Available ${formatAmountBigInt(balancePr.znn()!, znnDecimals, symbol: green('ZNN'))} and ${formatAmountBigInt(balancePr.qsr()!, qsrDecimals, symbol: blue('QSR'))}');
        break;
      }

      print(
          'Creating a new ${green('Pillar')} will burn the deposited ${blue('QSR')} required for the Pillar slot');
      if (!confirm('Do you want to proceed?', defaultValue: false)) break;

      bool okPr =
          (await znnClient.embedded.pillar.checkNameAvailability(namePr));
      while (!okPr) {
        namePr = ask(
            'This Pillar name is already reserved. Please choose another name for the Pillar');
        okPr = (await znnClient.embedded.pillar.checkNameAvailability(namePr));
      }
      if (depositedQsrPr == null || depositedQsrPr < qsrAmountPr) {
        BigInt amountToDeposit = qsrAmountPr - (depositedQsrPr ?? BigInt.zero);
        print(
            'Depositing ${formatAmountBigInt(amountToDeposit, qsrDecimals, symbol: blue('QSR'))} for the Pillar registration');
        await znnClient.send(
            znnClient.embedded.pillar.depositQsr(amountToDeposit));
      }
      print('Registering Pillar ...');
      await znnClient.send(znnClient.embedded.pillar.register(
          namePr,
          producerAddressPr,
          rewardAddressPr,
          giveBlockRewardPercentagePr,
          giveDelegateRewardPercentagePr));
      print('Done');
      print(
          'Check after 2 momentums if the Pillar was successfully registered using ${green('pillar.list')} command');
      break;

    case 'pillar.collect':
      await znnClient.send(znnClient.embedded.pillar.collectReward());
      print('Done');
      print(
          'Use ${green('receiveAll')} to collect your Pillar reward(s) after 1 momentum');
      break;

    case 'pillar.revoke':
      String namePrk = commandResults['name'];
      PillarInfoList pillarListPrk = (await znnClient.embedded.pillar.getAll());
      bool okPrk = false;
      for (PillarInfo pillar in pillarListPrk.list) {
        if (namePrk.compareTo(pillar.name) == 0) {
          okPrk = true;
          if (pillar.isRevocable) {
            print('Revoking Pillar ${pillar.name} ...');
            await znnClient.send(znnClient.embedded.pillar.revoke(namePrk));
            print(
                'Use ${green('receiveAll')} to collect back the locked amount of ${green('ZNN')}');
          } else {
            print(
                'Cannot revoke Pillar ${pillar.name}. Revocation window will open in ${formatDuration(pillar.revokeCooldown)}');
          }
        }
      }
      if (okPrk) {
        print('Done');
      } else {
        print('There is no Pillar with this name');
      }
      break;

    case 'pillar.delegate':
      String namePd = commandResults['name'];
      print('Delegating to Pillar $namePd ...');
      await znnClient.send(znnClient.embedded.pillar.delegate(namePd));
      print('Done');
      break;

    case 'pillar.undelegate':
      print('Undelegating ...');
      await znnClient.send(znnClient.embedded.pillar.undelegate());
      print('Done');
      break;

    case 'pillar.withdrawQsr':
      BigInt? depositedQsrPw = // Ensure this is BigInt?
          await znnClient.embedded.pillar.getDepositedQsr(address!);
      if (depositedQsrPw == null || depositedQsrPw == BigInt.zero) { // Check for null and zero
        print('No deposited ${blue('QSR')} to withdraw');
        break;
      }
      print(
          'Withdrawing ${formatAmountBigInt(depositedQsrPw, qsrDecimals, symbol: blue('QSR'))} ...');
      await znnClient.send(znnClient.embedded.pillar.withdrawQsr());
      print('Done');
      break;

    case 'token.list':
      int pageIndexTl = int.parse(commandResults['pageIndex']);
      int pageSizeTl = int.parse(commandResults['pageSize']);
      TokenList tokenList = await znnClient.embedded.token
          .getAll(pageIndex: pageIndexTl, pageSize: pageSizeTl);
      for (Token token in tokenList.list!) {
        if (token.tokenStandard == znnZts || token.tokenStandard == qsrZts) {
          print(
              '${token.tokenStandard == znnZts ? green(token.name) : blue(token.name)} with symbol ${token.tokenStandard == znnZts ? green(token.symbol) : blue(token.symbol)} and standard ${token.tokenStandard == znnZts ? green(token.tokenStandard.toString()) : blue(token.tokenStandard.toString())}');
          print(
              '   Created by ${token.tokenStandard == znnZts ? green(token.owner.toString()) : blue(token.owner.toString())}');
          print(
              '   ${token.tokenStandard == znnZts ? green(token.name) : blue(token.name)} has ${token.decimals} decimals, ${token.isMintable ? 'is mintable' : 'is not mintable'}, ${token.isBurnable ? 'can be burned' : 'cannot be burned'}, and ${token.isUtility ? 'is a utility coin' : 'is not a utility coin'}');
          print(
              '   The total supply is ${formatAmountBigInt(token.totalSupply, token.decimals, symbol: token.symbol)} and the maximum supply is ${formatAmountBigInt(token.maxSupply, token.decimals, symbol: token.symbol)}');
        } else {
          print(
              'Token ${token.name} with symbol ${token.symbol} and standard ${magenta(token.tokenStandard.toString())}');
          print('   Issued by ${token.owner.toString()}');
          print(
              '   ${token.name} has ${token.decimals} decimals, ${token.isMintable ? 'can be minted' : 'cannot be minted'}, ${token.isBurnable ? 'can be burned' : 'cannot be burned'}, and ${token.isUtility ? 'is a utility token' : 'is not a utility token'}');
        }
        print('   Domain `${token.domain}`');
      }
      break;

    case 'token.getByStandard':
      TokenStandard tokenStandardTgs = TokenStandard.parse(commandResults['tokenStandard']);
      Token tokenTgs = (await znnClient.embedded.token.getByZts(tokenStandardTgs))!;
      String typeTgs = 'Token';
      if (tokenTgs.tokenStandard.toString() == qsrTokenStandard ||
          tokenTgs.tokenStandard.toString() == znnTokenStandard) {
        typeTgs = 'Coin';
      }
      print(
          '$typeTgs ${tokenTgs.name} with symbol ${tokenTgs.symbol} and standard ${tokenTgs.tokenStandard.toString()}');
      print('   Created by ${green(tokenTgs.owner.toString())}');
      print(
          '   The total supply is ${formatAmountBigInt(tokenTgs.totalSupply, tokenTgs.decimals, symbol: tokenTgs.symbol)} and a maximum supply is ${formatAmountBigInt(tokenTgs.maxSupply, tokenTgs.decimals, symbol: tokenTgs.symbol)}');
      print(
          '   The token has ${tokenTgs.decimals} decimals ${tokenTgs.isMintable ? 'can be minted' : 'cannot be minted'} and ${tokenTgs.isBurnable ? 'can be burned' : 'cannot be burned'}');
      break;

    case 'token.getByOwner':
      String typeTgo = 'Token';
      Address ownerAddressTgo = Address.parse(commandResults['ownerAddress']);
      TokenList tokensTgo =
          await znnClient.embedded.token.getByOwner(ownerAddressTgo);
      for (Token token in tokensTgo.list!) {
        typeTgo = 'Token';
        if (token.tokenStandard.toString() == znnTokenStandard ||
            token.tokenStandard.toString() == qsrTokenStandard) {
          typeTgo = 'Coin';
        }
        print(
            '$typeTgo ${token.name} with symbol ${token.symbol} and standard ${token.tokenStandard.toString()}');
        print('   Created by ${green(token.owner.toString())}');
        print(
            '   The total supply is ${formatAmountBigInt(token.totalSupply, token.decimals, symbol: token.symbol)} and a maximum supply is ${formatAmountBigInt(token.maxSupply, token.decimals, symbol: token.symbol)}');
        print(
            '   The token ${token.decimals} decimals ${token.isMintable ? 'can be minted' : 'cannot be minted'} and ${token.isBurnable ? 'can be burned' : 'cannot be burned'}');
      }
      break;

    case 'token.issue':
      String nameTi = commandResults['name'];
      String symbolTi = commandResults['symbol'];
      String domainTi = commandResults['domain'];
      int totalSupplyTi = int.parse(commandResults['totalSupply']);
      int maxSupplyTi = int.parse(commandResults['maxSupply']);
      int decimalsTi = int.parse(commandResults['decimals']);
      bool isMintableTi = commandResults['isMintable'].toLowerCase() == 'true' || commandResults['isMintable'] == '1';
      bool isBurnableTi = commandResults['isBurnable'].toLowerCase() == 'true' || commandResults['isBurnable'] == '1';
      bool isUtilityTi = commandResults['isUtility'].toLowerCase() == 'true' || commandResults['isUtility'] == '1';

      RegExp regExpName = RegExp(r'^([a-zA-Z0-9]+[-._]?)*[a-zA-Z0-9]$');
      if (!regExpName.hasMatch(nameTi)) {
        print('${red("Error!")} The ZTS name contains invalid characters');
        break;
      }

      RegExp regExpSymbol = RegExp(r'^[A-Z0-9]+$');
      if (!regExpSymbol.hasMatch(symbolTi)) {
        print('${red("Error!")} The ZTS symbol must be all uppercase');
        break;
      }

      RegExp regExpDomain = RegExp(
          r'^([A-Za-z0-9][A-Za-z0-9-]{0,61}[A-Za-z0-9]\.)+[A-Za-z]{2,}$');
      if (domainTi.isEmpty || !regExpDomain.hasMatch(domainTi)) {
        print('${red("Error!")} Invalid domain');
        print('Examples of ${green('valid')} domain names:');
        print('    zenon.network');
        print('    www.zenon.network');
        print('    quasar.zenon.network');
        print('    zenon.community');
        print('Examples of ${red('invalid')} domain names:');
        print('    zenon.network/index.html');
        print('    www.zenon.network/quasar');
        break;
      }

      if (nameTi.isEmpty || nameTi.length > 40) {
        print(
            '${red("Error!")} Invalid ZTS name length (min 1, max 40, current ${nameTi.length})');
        break;
      }

      if (symbolTi.isEmpty || symbolTi.length > 10) {
        print(
            '${red("Error!")} Invalid ZTS symbol length (min 1, max 10, current ${symbolTi.length})');
        break;
      }

      if (domainTi.length > 128) {
        print(
            '${red("Error!")} Invalid ZTS domain length (min 0, max 128, current ${domainTi.length})');
        break;
      }

      if (isMintableTi == true) {
        if (maxSupplyTi < totalSupplyTi) {
          print(
              '${red("Error!")} Max supply must to be larger than the total supply');
          break;
        }
        if (maxSupplyTi > (1 << 53)) {
          print(
              '${red("Error!")} Max supply must to be less than ${((1 << 53)) - 1}');
          break;
        }
      } else {
        if (maxSupplyTi != totalSupplyTi) {
          print(
              '${red("Error!")} Max supply must be equal to totalSupply for non-mintable tokens');
          break;
        }
        if (totalSupplyTi == 0) {
          print(
              '${red("Error!")} Total supply cannot be "0" for non-mintable tokens');
          break;
        }
      }

      print('Issuing a new ${green('ZTS token')} will burn 1 ZNN');
      if (!confirm('Do you want to proceed?', defaultValue: false)) break;

      print('Issuing $nameTi ZTS token ...');
      await znnClient.send(znnClient.embedded.token.issueToken(
          nameTi,
          symbolTi,
          domainTi,
          totalSupplyTi,
          maxSupplyTi,
          decimalsTi,
          isMintableTi,
          isBurnableTi,
          isUtilityTi));
      print('Done');
      break;

    case 'token.mint':
      TokenStandard tokenStandardTm = TokenStandard.parse(commandResults['tokenStandard']);
      Token? tokenInfoForMint = await znnClient.embedded.token.getByZts(tokenStandardTm);
      if (tokenInfoForMint == null) {
        print(red("Error: Token standard ${commandResults['tokenStandard']} not found."));
        break;
      }
      BigInt amountTm = parseAmountToBigInt(commandResults['amount'], tokenInfoForMint.decimals);
      Address mintAddressTm = Address.parse(commandResults['receiveAddress']);

      // Token? tokenTm = await znnClient.embedded.token.getByZts(tokenStandardTm); // This is redundant, use tokenInfoForMint
      // Token? tokenTm = await znnClient.embedded.token.getByZts(tokenStandardTm); // This is redundant, use tokenInfoForMint
      if (tokenInfoForMint.isMintable == false) {
        print('${red("Error!")} The token is not mintable');
        break;
      }

      print('Minting ZTS token ...');
      await znnClient.send(
          znnClient.embedded.token.mintToken(tokenStandardTm, amountTm, mintAddressTm));
      print('Done');
      break;

    case 'token.burn':
      TokenStandard tokenStandardTb = TokenStandard.parse(commandResults['tokenStandard']);
      Token? tokenInfoForBurn = await znnClient.embedded.token.getByZts(tokenStandardTb);
      if (tokenInfoForBurn == null) {
        print(red("Error: Token standard ${commandResults['tokenStandard']} not found."));
        break;
      }
      BigInt amountTb = parseAmountToBigInt(commandResults['amount'], tokenInfoForBurn.decimals);

      AccountInfo balanceInfoForBurn = await znnClient.ledger.getAccountInfoByAddress(address!);
      var tokenToBurnDetails = balanceInfoForBurn.getBalance(tokenStandardTb);
      bool okTb = true;

      if (tokenToBurnDetails == null || tokenToBurnDetails.balance! < amountTb) {
         print(
              '${red("Error!")} You only have ${formatAmountBigInt(tokenToBurnDetails?.balance ?? BigInt.zero, tokenInfoForBurn.decimals, symbol: tokenInfoForBurn.symbol)} ${tokenInfoForBurn.symbol} tokens to burn.');
        okTb = false;
      }

      if (!okTb) break;
      print('Burning ${formatAmountBigInt(amountTb, tokenInfoForBurn.decimals, symbol: tokenInfoForBurn.symbol)} ${tokenInfoForBurn.symbol} tokens ...');
      await znnClient
          .send(znnClient.embedded.token.burnToken(tokenStandardTb, amountTb));
      print('Done');
      break;

    case 'token.transferOwnership':
      TokenStandard tokenStandardTto = TokenStandard.parse(commandResults['tokenStandard']);
      Address newOwnerAddressTto = Address.parse(commandResults['newOwnerAddress']);
      print('Transferring ZTS token ownership ...');
      var tokenTto = (await znnClient.embedded.token.getByZts(tokenStandardTto))!;
      if (tokenTto.owner.toString() != address!.toString()) {
        print('${red('Error!')} Not owner of token ${commandResults['tokenStandard']}');
        break;
      }
      await znnClient.send(znnClient.embedded.token.updateToken(
          tokenStandardTto, newOwnerAddressTto, tokenTto.isMintable, tokenTto.isBurnable));
      print('Done');
      break;

    case 'token.disableMint':
      TokenStandard tokenStandardTdm = TokenStandard.parse(commandResults['tokenStandard']);
      print('Disabling ZTS token mintable flag ...');
      var tokenTdm = (await znnClient.embedded.token.getByZts(tokenStandardTdm))!;
      if (tokenTdm.owner.toString() != address!.toString()) {
        print('${red('Error!')} Not owner of token ${commandResults['tokenStandard']}');
        break;
      }
      await znnClient.send(znnClient.embedded.token
          .updateToken(tokenStandardTdm, tokenTdm.owner, false, tokenTdm.isBurnable));
      print('Done');
      break;

    case 'wallet.createNew':
      String passphraseWcn = commandResults['passphrase'];
      String? nameWcn = commandResults['keyStoreName'];
      File keyStoreWcn = await znnClient.keyStoreManager.createNew(passphraseWcn, nameWcn);
      print(
          'keyStore ${green('successfully')} created: ${path.basename(keyStoreWcn.path)}');
      break;

    case 'wallet.createFromMnemonic':
      String mnemonicWcfm = commandResults['mnemonic'];
      String passphraseWcfm = commandResults['passphrase'];
      String? nameWcfm = commandResults['keyStoreName'];
      if (!bip39.validateMnemonic(mnemonicWcfm)) {
        throw AskValidatorException(red('Invalid mnemonic'));
      }
      File keyStoreWcfm = await znnClient.keyStoreManager
          .createFromMnemonic(mnemonicWcfm, passphraseWcfm, nameWcfm);
      print(
          'keyStore ${green('successfully')} created from mnemonic: ${path.basename(keyStoreWcfm.path)}');
      break;

    case 'wallet.dumpMnemonic':
      print('Mnemonic for keyStore ${znnClient.defaultKeyStorePath!}');
      print(znnClient.defaultKeyStore!.mnemonic);
      break;

    case 'wallet.export':
      String filePathWe = commandResults['filePath'];
      await znnClient.defaultKeyStorePath!.copy(filePathWe);
      print('Done! Check the current directory');
      break;

    case 'wallet.list':
      List<File> stores = await znnClient.keyStoreManager.listAllKeyStores();
      if (stores.isNotEmpty) {
        print('Available keyStores:');
        for (File store in stores) {
          print(path.basename(store.path));
        }
      } else {
        print('No keyStores found');
      }
      break;

    case 'wallet.deriveAddresses':
      print('Addresses for keyStore ${znnClient.defaultKeyStorePath!}');
      int leftWda = int.parse(commandResults['left']);
      int rightWda = int.parse(commandResults['right']);
      List<Address?> addressesWda =
          await znnClient.defaultKeyStore!.deriveAddressesByRange(leftWda, rightWda);
      for (int i = 0; i < rightWda - leftWda; i += 1) {
        print('  ${i + leftWda}\t${addressesWda[i].toString()}');
      }
      break;

    case 'sendEncryptedMessage':
      final String toAddressStringSem = commandResults['to'];
      final String messageSem = commandResults['message'];
      final String? mnemonicSem = commandResults['mnemonic'];
      KeyPair? keyPairSem = znnClient.defaultKeyPair;

      if (mnemonicSem != null && mnemonicSem.isNotEmpty) {
        print('Using provided mnemonic for sendEncryptedMessage.');
        if (!bip39.validateMnemonic(mnemonicSem)) {
          print(red('Error: Invalid mnemonic provided.'));
          return;
        }
        KeyStore ks = KeyStore.fromMnemonic(mnemonicSem);
        keyPairSem = await ks.getManager().deriveKey(); // Default is account 0
        print('Derived address from mnemonic: ${(await keyPairSem.address).toString()}');
      }

      if (keyPairSem == null) {
        print(red('Error: Could not determine keypair for sending. Ensure a default keypair is set or provide a mnemonic.'));
        return;
      }

      Address toAddressSem = Address.parse(toAddressStringSem);
      final frontierSem =
          await znnClient.ledger.getFrontierAccountBlock(toAddressSem);
      if (frontierSem == null) {
        print(
            'Can\'t fetch recipient public key because the recipient\'s account chain is empty.');
        break;
      }

      final x25519pkSem = Sodium().cryptoSignEd25519PkToCurve25519(
          Uint8List.fromList(frontierSem.publicKey));
      final sealSem = Sodium()
          .cryptoBoxSeal(Uint8List.fromList(utf8.encode(messageSem)), x25519pkSem)
          .toList();

      // Ensure the amount is BigInt.zero for messages with no ZNN/QSR transfer
      final blockSem = AccountBlockTemplate.send(
          toAddressSem, TokenStandard.parse(emptyTokenStandard), BigInt.zero);
      blockSem.data = sealSem;
      print('Sending encrypted message to $toAddressStringSem');
      print('Data size: ${blockSem.data.length}');
      // Use the derived or default keyPair to send the transaction
      await znnClient.send(blockSem, keyPair: keyPairSem);
      print('Done');
      break;

    case 'decryptMessage':
      final String encryptedMessageDm = commandResults['message'];
      final String? mnemonicDm = commandResults['mnemonic'];
      KeyPair? keyPairDm = znnClient.defaultKeyPair;

      if (mnemonicDm != null && mnemonicDm.isNotEmpty) {
        print('Using provided mnemonic for decryptMessage.');
        if (!bip39.validateMnemonic(mnemonicDm)) {
          print(red('Error: Invalid mnemonic provided.'));
          return;
        }
        KeyStore ks = KeyStore.fromMnemonic(mnemonicDm);
        keyPairDm = await ks.getManager().deriveKey();
        print('Derived address from mnemonic: ${(await keyPairDm.address).toString()}');
      }

      if (keyPairDm == null) {
        print(red('Error: Could not determine keypair for decryption. Ensure a default keypair is set or provide a mnemonic.'));
        return;
      }

      final x25519pkDm = Sodium().cryptoSignEd25519PkToCurve25519(
          Uint8List.fromList(keyPairDm.publicKey!));
      final x25519skDm = Sodium().cryptoSignEd25519SkToCurve25519(
          Uint8List.fromList(keyPairDm.privateKey!));
      try {
        print(utf8.decode(Sodium()
            .cryptoBoxSealOpen(base64Decode(encryptedMessageDm), x25519pkDm, x25519skDm)
            .toList()));
      } catch (e) {
        print(red('Error during decryption: ${e.toString()}'));
        print('Ensure the message was encrypted for the correct public key and the mnemonic is correct if provided.');
      }
      break;
    // No default needed here as parser.parse(args) would have already thrown an error
    // for an unrecognized command, which is caught above.
  }
  return;
}
