{
  description = "Logos qr_signer_ui — the QR signer's app: air-gapped wallets' accounts, added from their codes.";

  inputs = {
    # Pinned to builder#276 (postFixup), which the scanner needs, until it reaches master.
    logos-module-builder.url = "github:logos-co/logos-module-builder/ac4ff31674bef3860ef10c2883e719452e573418";
    # Pinned to the module's first branch until it reaches main.
    qr_signer_module = {
      url = "github:logos-co/logos-qr-signer-module/62616c7924a25e596c87d5bb1beee7bfbece28a8";
      inputs.logos-module-builder.follows = "logos-module-builder";
    };
    # OPTIONAL: a wallet's account code is read here, in the Add dialog, not in a window of the
    # scanner's. It hands over whether a code is in view and the parts read, never a picture, and
    # only the scans qr_signer_module starts. Pinned to the module's first branch until it reaches main.
    qr_scanner_module = {
      url = "github:logos-co/logos-qr-scanner-module/58406b3a98678d99bd70674cdd4df5bcb1f7c934";
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
