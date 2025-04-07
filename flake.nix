{
  description = "A Nix-flake-based C/C++ development environment";
  
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    nix-vscode-extensions = {
      url = "github:nix-community/nix-vscode-extensions";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-utils.follows = "flake-utils";
      };
    };
  };

  outputs = { self, nixpkgs, flake-utils, nix-vscode-extensions }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
        inherit (pkgs) vscode-with-extensions vscodium;
        extensions = nix-vscode-extensions.extensions.${system};
        
        customVSCodium = pkgs.vscode-with-extensions.override {
          vscode = vscodium;
          vscodeExtensions = with extensions; [
            vscode-marketplace.llvm-vs-code-extensions.vscode-clangd
            vscode-marketplace-release.github.copilot
            vscode-marketplace-release.github.copilot-chat
            open-vsx.catppuccin.catppuccin-vsc
            open-vsx.jnoortheen.nix-ide
          ];
        };

        mpv-dev = pkgs.mpv-unwrapped.overrideAttrs (oldAttrs: {
          src = self;
          postPatch = builtins.concatStringsSep "\n" [
            # Don't reference compile time dependencies or create a build outputs cycle
            # between out and dev
            ''
              substituteInPlace meson.build \
                --replace-fail "conf_data.set_quoted('CONFIGURATION', meson.build_options())" \
                              "conf_data.set_quoted('CONFIGURATION', '<omitted>')"
            ''
            # A trick to patchShebang everything except mpv_identify.sh
            ''
              pushd TOOLS
              mv mpv_identify.sh mpv_identify
              patchShebangs *.py *.sh
              mv mpv_identify mpv_identify.sh
              popd
            ''
          ];
        });

        commonPackages = with pkgs; [
          customVSCodium
          clang-tools
          linuxKernel.packages.linux_6_6.perf
          cmake
          meson
          ninja
          codespell
          conan
          cppcheck
          doxygen
          gtest
          lcov
          vcpkg
          vcpkg-tool
        ];

        systemSpecificPackages = with pkgs;
          if system == "aarch64-darwin"
          then []
          else [ gdb ];
      in
      {
        packages = {
          default = mpv-dev;
          mpv-dev = mpv-dev;
        };

        devShells.default = pkgs.mkShell {
          name = "mpv-dev";
          inputsFrom = mpv-dev.buildInputs;
          packages = commonPackages ++ systemSpecificPackages;
        };
      });
}