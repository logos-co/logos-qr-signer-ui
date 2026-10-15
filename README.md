# logos-qr-signer-ui

`qr_signer_ui` is the QR signer's app, for air-gapped wallets that sign over animated QR codes: the
Keycard Shell, Keystone, Passport, Jade and others. It adds a wallet's accounts from the account code
the wallet shows, and lists the accounts offered, with a way to take one back. The signer manager
then lists those accounts beside the keystore's, and the wallet signs each request it is shown.

No secret crosses it: the keys stay on the wallet, and only the public keys in its code are kept.
Everything goes through [`qr_signer_module`](https://github.com/logos-co/logos-qr-signer-module),
which reads codes through [`qr_scanner_module`](https://github.com/logos-co/logos-qr-scanner-module):
the camera is asked for in the name of Logos QR, never this app's.

| On screen | The module's |
|---|---|
| Which wallet: as its code says, or one the signer knows by name | `profiles` |
| EVM, native segwit, taproot; name; Read the wallet's code | `scan_accounts`, then `add_status` until the code is read |
| Offered to apps; Remove | `signer_accounts`, `remove_account` |

The accounts are on the network the wallet is set to: a code with `m/84'/1'/0'` gives a test network
account.

```sh
nix build .#lgx
```

[`doctests/qr-signer-ui-e2e.test.yaml`](doctests/qr-signer-ui-e2e.test.yaml) drives the app
headlessly through the QML inspector. The scanner's helper runs in fake mode against
`qr-device-emulator`, a QR wallet in software, so no camera is needed.

Licensed under MIT or Apache-2.0.
