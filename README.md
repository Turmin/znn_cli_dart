# Zenon Command Line Interface (znn-cli) - Dart

A command-line interface for interacting with the Zenon Network (Network of Momentum - Phase 1). This tool allows you to manage your wallet, send transactions, interact with embedded contracts (Plasma, Sentinel, Stake, Pillar, Token), and use encrypted messaging.

## Features

*   Wallet management (create new, import from mnemonic, list addresses, export keystore).
*   Send ZNN, QSR, and ZTS tokens, with support for accompanying messages.
*   Receive transactions individually or automatically.
*   Check address balances and unreceived/unconfirmed transactions.
*   Full interaction with Plasma (fuse, cancel, list entries).
*   Full interaction with Sentinels (register, revoke, collect rewards, manage QSR deposit).
*   Full interaction with Staking (stake ZNN, revoke stake, collect rewards).
*   Full interaction with Pillars (list, register, revoke, delegate, collect rewards, manage QSR deposit).
*   Issue and manage ZTS tokens (list, get by standard/owner, issue, mint, burn, transfer ownership, disable mint).
*   Send and decrypt end-to-end encrypted messages using default wallet keys or a provided 24-word mnemonic phrase.
*   Compatible with Zenon Network of Momentum - Phase 1 (utilizes BigInt for all token amounts).

## Prerequisites

*   Dart SDK (version >=2.14.0 <3.0.0). You can find installation instructions at [https://dart.dev/get-dart](https://dart.dev/get-dart).
*   Git.

## Building and Installation

1.  **Clone the Repository**:
    ```bash
    git clone https://github.com/Turmin/znn_cli_dart.git
    cd znn_cli_dart
    ```

2.  **Build the Executable**:

    *   **Option 1: Using `make` (Recommended)**
        This is the simplest method as it handles compilation and resource copying.
        ```bash
        make
        ```
        The executable (`znn-cli` or `znn-cli.exe`) and necessary resource files will be placed in the `build/` directory.

    *   **Option 2: Manual Compilation**
        If you prefer or `make` is not available:
        ```bash
        # Ensure dependencies are fetched
        dart pub get

        # Create the build directory if it doesn't exist
        mkdir -p build

        # Compile the Dart code
        dart compile exe cli_handler.dart -o build/znn-cli
        # On Windows, the output will be build/znn-cli.exe

        # Copy necessary resource files
        # On Linux/macOS:
        cp ./Resources/* ./build/
        # On Windows:
        # xcopy Resources build /E /I /Y
        ```

3.  **Running the CLI**:
    After building, the executable (`znn-cli` or `znn-cli.exe`) and the resource files (e.g., `libargon2_ffi_plugin.so`, `libpow_links.dll`, etc.) will be in the `build/` directory.

    **Important**: To run the CLI, ensure the executable is run from within the `build/` directory:
    ```bash
    cd build
    ./znn-cli --version
    ```
    Alternatively, if you move the executable elsewhere, ensure all files originally copied from the `Resources/` directory are present in the same directory as the `znn-cli` executable. These files are required for certain functionalities like wallet operations and Proof of Work.

4.  **(Optional) Adding to PATH**:
    For easier access, you can add the `build/` directory to your system's PATH environment variable. Alternatively, move the `znn-cli` executable (along with all the files from `Resources/`) to a directory that is already in your system's PATH (e.g., `/usr/local/bin` on Linux/macOS).

## Wallet Setup

Before performing most operations, you'll need a wallet (keyStore file).

*   **Create a new wallet**:
    ```bash
    ./build/znn-cli wallet.createNew --passphrase "your_strong_passphrase"
    # You can optionally add --keyStoreName your_wallet_name.json
    ```

*   **Import a wallet from a mnemonic phrase**:
    ```bash
    ./build/znn-cli wallet.createFromMnemonic --mnemonic "your 24 word mnemonic phrase exactly as it is" --passphrase "your_strong_passphrase"
    ```

*   **List available wallets**:
    ```bash
    ./build/znn-cli wallet.list
    ```
    This will show keyStore files in the default Zenon wallet directory.

## Usage Examples

The general syntax is:
`./build/znn-cli [GLOBAL_OPTIONS] <COMMAND> [COMMAND_OPTIONS]`

### Global Options
*   `--url <node_url>`: Specify the Zenon node WebSocket URL (e.g., `ws://127.0.0.1:35997`). Defaults to `ws://127.0.0.1:35997`.
*   `--keyStore <keystore_filename.json>`: Specify the keyStore file to use (located in the default Zenon wallet directory).
*   `--passphrase <passphrase>`: Provide the passphrase for the keyStore. If not provided, you'll be prompted securely.
*   `--index <address_index>`: Specify the address index within the keyStore. Defaults to 0.
*   `--help`: Display general help information.
*   `--verbose`: Print detailed information about the performed action.

### Common Commands

**Check Balance:**
Assumes `mywallet.json` is in your default Zenon wallet directory.
```bash
./build/znn-cli balance --keyStore mywallet.json --passphrase "your_passphrase"
```

**Send ZNN:**
```bash
./build/znn-cli send --toAddress z1qx... --amount "10.5" --tokenStandard ZNN --keyStore mywallet.json --passphrase "your_passphrase"
```

**Send QSR with a message:**
```bash
./build/znn-cli send --toAddress z1qx... --amount "1.23" --tokenStandard QSR --message "Hello Zenon from CLI" --keyStore mywallet.json --passphrase "your_passphrase"
```

### Encrypted Messaging

**Send an Encrypted Message (using default keyStore):**
```bash
./build/znn-cli sendEncryptedMessage --to z1recipientaddress... --message "This is a secret message!" --keyStore mywallet.json --passphrase "your_passphrase"
```

**Send an Encrypted Message (using a specific mnemonic):**
This does not require a keyStore file as the keys are derived directly from the mnemonic.
```bash
./build/znn-cli sendEncryptedMessage --to z1recipientaddress... --message "Top secret info from mnemonic." --mnemonic "decorate ketchup auto tired truck flip feel fatal flock goddess menu club accuse glide stone leaf country certain rapid liquid moral envelope silly fetch"
```

**Decrypt a Message (using default keyStore):**
```bash
./build/znn-cli decryptMessage --message "BASE64_ENCRYPTED_DATA_HERE" --keyStore mywallet.json --passphrase "your_passphrase"
```

**Decrypt a Message (using a specific mnemonic):**
This does not require a keyStore file.
```bash
./build/znn-cli decryptMessage --message "BASE64_ENCRYPTED_DATA_HERE" --mnemonic "decorate ketchup auto tired truck flip feel fatal flock goddess menu club accuse glide stone leaf country certain rapid liquid moral envelope silly fetch"
```

**Note**: For a full list of commands and their specific options, run `./build/znn-cli --help` or get help for a specific command like `./build/znn-cli send --help`.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Contributing

Contributions are welcome. Please see the [CONTRIBUTING.md](CONTRIBUTING.md) file for guidelines.
