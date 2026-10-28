{
  description = "Logos qr_signer_ui — the QR signer's app: air-gapped wallets' accounts, added from their codes.";

  inputs = {
    logos-module-builder.url = "github:logos-co/logos-module-builder";
    qr_signer_module = {
      url = "github:logos-co/logos-qr-signer-module";
      inputs.logos-module-builder.follows = "logos-module-builder";
      inputs.qr_scanner_module.follows = "qr_scanner_module";
    };
    # OPTIONAL: a wallet's account code is read here, in the Add dialog, not in a window of the
    # scanner's. It hands over whether a code is in view and the parts read, never a picture, and
    # only the scans qr_signer_module starts.
    qr_scanner_module = {
      url = "github:logos-co/logos-qr-scanner-module";
      inputs.logos-module-builder.follows = "logos-module-builder";
    };
  };

  # mkLogosQmlModule assembles the QML into the package, which the .lgx step needs.
  outputs = inputs@{ logos-module-builder, ... }:
    logos-module-builder.lib.mkLogosQmlModule {
      src = ./.;
      configFile = ./metadata.json;
      flakeInputs = inputs;
    };
}
