{
  description = "Logos qr_signer_ui — the QR signer's app: air-gapped wallets' accounts, added from their codes.";

  inputs = {
    # Pinned to builder#276 (postFixup), which the scanner needs, until it reaches master.
    logos-module-builder.url = "github:logos-co/logos-module-builder/ac4ff31674bef3860ef10c2883e719452e573418";
    # Pinned to the module's first branch until it reaches main.
    qr_signer_module = {
      url = "github:logos-co/logos-qr-signer-module/a70b81e0c81c0df8e199e3a6d1027d3537a7a56e";
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
