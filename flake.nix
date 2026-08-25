{
  description = "TerraTech Steam Mod Manager - Nix flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };

        version = "1.7.10";

        # Use the oldest available Electron in nixpkgs
        electron = pkgs.electron_37;

        src = pkgs.fetchFromGitHub {
          owner = "FLSoz";
          repo = "terratech-steam-mod-manager";
          rev = "v${version}";
          # ⚠️ PLACEHOLDER — replace after first `nix build` attempt.
          # Nix will print the expected hash on failure.
          hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
        };

        # Shared native libs for Electron runtime and native Node addons
        runtimeDeps = with pkgs; [
          libusb1
          udev
          # X11 / display
          libx11
          libxext
          libxrender
          libxi
          libxtst
          libxrandr
          libxdamage
          libxcomposite
          libxcursor
          libxfixes
          libxscrnsaver
          libxkbcommon
          # Graphics
          mesa
          libdrm
          # Electron runtime deps
          nss
          nspr
          atk
          at-spi2-atk
          cups
          gtk3
          pango
          cairo
          gdk-pixbuf
          glib
          dbus
          expat
          libuuid
          # Audio
          alsa-lib
          pulseaudio
          pipewire
        ];

        terratech-steam-mod-manager = pkgs.buildNpmPackage {
          pname = "terratech-steam-mod-manager";
          inherit version src;

          # ⚠️ PLACEHOLDER — replace after first `nix build` attempt.
          npmDepsHash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";

          # Skip lifecycle scripts during dependency fetch;
          # we handle native rebuilds and DLL builds ourselves.
          npmFlags = [ "--ignore-scripts" ];

          nativeBuildInputs = with pkgs; [
            nodejs_22
            python3
            pkg-config
            makeWrapper
            node-gyp
            gcc
            gnumake
          ];

          buildInputs = runtimeDeps;

          # Don't download Electron binary — we use Nix's packaged Electron
          ELECTRON_SKIP_BINARY_DOWNLOAD = "1";

          buildPhase = ''
            runHook preBuild

            export HOME=$TMPDIR

            # ── Install native deps for release/app ──────────────────────
            # The upstream postinstall runs `electron-builder install-app-deps`
            # which compiles native modules inside release/app. We replicate
            # that manually since we skip lifecycle scripts.
            pushd release/app
              mkdir -p node_modules
              npm ci --ignore-scripts || npm install --ignore-scripts
              # Rebuild native modules against Nix's headers
              npx electron-rebuild -f -w greenworks,ps-list \
                -m . || true
            popd

            # ── Build DLL (renderer dev bundle) ──────────────────────────
            npx cross-env NODE_ENV=development \
              TS_NODE_TRANSPILE_ONLY=true \
              NODE_OPTIONS="-r ts-node/register --no-warnings" \
              webpack --config ./.erb/configs/webpack.config.renderer.dev.dll.ts

            # ── Build main process ───────────────────────────────────────
            npx cross-env NODE_ENV=production \
              TS_NODE_TRANSPILE_ONLY=true \
              NODE_OPTIONS="-r ts-node/register --no-warnings" \
              webpack --config ./.erb/configs/webpack.config.main.prod.ts

            # ── Build renderer ───────────────────────────────────────────
            npx cross-env NODE_ENV=production \
              TS_NODE_TRANSPILE_ONLY=true \
              NODE_OPTIONS="-r ts-node/register --no-warnings" \
              webpack --config ./.erb/configs/webpack.config.renderer.prod.ts

            runHook postBuild
          '';

          installPhase = ''
            runHook preInstall

            appDir=$out/lib/terratech-steam-mod-manager
            mkdir -p $appDir
            mkdir -p $out/bin
            mkdir -p $out/share/applications
            mkdir -p $out/share/icons/hicolor/512x512/apps

            # Copy built bundles + runtime node_modules
            cp -r release/app/dist        $appDir/dist
            cp -r release/app/node_modules $appDir/node_modules
            cp    release/app/package.json  $appDir/package.json

            # Copy assets (icons, etc.)
            [ -d assets ] && cp -r assets $appDir/assets

            # ── Desktop entry ────────────────────────────────────────────
            cat > $out/share/applications/terratech-steam-mod-manager.desktop << 'DESKTOP'
[Desktop Entry]
Name=TerraTech Steam Mod Manager
Comment=Mod manager for TerraTech Steam Workshop mods
Exec=terratech-steam-mod-manager %U
Icon=terratech-steam-mod-manager
Type=Application
Categories=Game;Utility;
StartupWMClass=terratech-steam-mod-manager
DESKTOP

            # ── Icon ─────────────────────────────────────────────────────
            for candidate in assets/icon.png assets/icons/icon.png assets/icon_512.png; do
              if [ -f "$candidate" ]; then
                cp "$candidate" $out/share/icons/hicolor/512x512/apps/terratech-steam-mod-manager.png
                break
              fi
            done

            # ── Wrapper ──────────────────────────────────────────────────
            makeWrapper ${electron}/bin/electron $out/bin/terratech-steam-mod-manager \
              --add-flags "$appDir" \
              --set NODE_ENV production \
              --prefix LD_LIBRARY_PATH : "${pkgs.lib.makeLibraryPath runtimeDeps}"

            runHook postInstall
          '';

          meta = with pkgs.lib; {
            description = "Mod manager for TerraTech Steam Workshop mods";
            homepage = "https://github.com/FLSoz/terratech-steam-mod-manager";
            license = licenses.mit;
            maintainers = [ ];
            platforms = [ "x86_64-linux" "aarch64-linux" ];
            mainProgram = "terratech-steam-mod-manager";
          };
        };
      in
      {
        packages = {
          default = terratech-steam-mod-manager;
          terratech-steam-mod-manager = terratech-steam-mod-manager;
        };

        # Development shell with all build dependencies
        devShells.default = pkgs.mkShell {
          inputsFrom = [ terratech-steam-mod-manager ];
          packages = with pkgs; [
            electron_37
            nodePackages.cross-env
          ];

          shellHook = ''
            echo "TerraTech Steam Mod Manager — dev shell"
            echo "  node $(node --version)  |  electron $(electron --version)"
            echo ""
            echo "Build manually:"
            echo "  npm ci --ignore-scripts"
            echo "  cd release/app && npm ci --ignore-scripts && cd ../.."
            echo "  npm run build:dll"
            echo "  npm run build"
            echo "  electron ."
          '';
        };
      }
    );
}
