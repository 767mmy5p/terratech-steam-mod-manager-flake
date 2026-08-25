# Terratech Steam Mod Manager flake

Nix flake for [TerraTech Steam Mod Manager](https://github.com/FLSoz/terratech-steam-mod-loader)

## Prerequisites

- **Nix** with flakes enabled (`nix-command flakes` experimental features)
- **Steam** installed (the mod manager interacts with Steam Workshop)

## Usage

### Run directly

```bash
nix run github:767mmy5p/terratech-steam-mod-manager-flake
```

### Install via profile

```bash
nix profile install github:767mmy5p/terratech-steam-mod-manager-flake
```

### Add to NixOS system packages

```nix
# flake.nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    terratech-mod-manager.url = "github:767mmy5p/terratech-steam-mod-manager-flake";
  };

  outputs = { nixpkgs, terratech-mod-manager, ... }: {
    nixosConfigurations.my-host = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ({ pkgs, ... }: {
          environment.systemPackages = [
            terratech-mod-manager.packages.x86_64-linux.default
          ];
        })
      ];
    };
  };
}
```

### Add to Home Manager

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager";
    terratech-mod-manager.url = "github:767mmy5p/terratech-steam-mod-manager-flake";
  };

  outputs = { nixpkgs, home-manager, terratech-mod-manager, ... }: {
    homeConfigurations.my-user = home-manager.lib.homeManagerConfiguration {
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
      modules = [
        {
          home.packages = [
            terratech-mod-manager.packages.x86_64-linux.default
          ];
        }
      ];
    };
  };
}
```

### Development shell

Clone this repo and enter the dev environment:

```bash
git clone https://github.com/767mmy5p/terratech-steam-mod-manager-flake.git
cd terratech-steam-mod-manager-flake
nix develop
```

Inside the shell you can build manually:

```bash
npm ci --ignore-scripts
npm run build:dll
npm run build
electron .
```

## Building

```bash
nix build
```

The output binary is at `./result/bin/terratech-steam-mod-manager`.

## Important Notes

### `greenworks` native dependency

The upstream project depends on [`greenworks`](https://github.com/greenheartgames/greenworks), a native Node.js addon for Steam integration. This module requires the **Steamworks SDK** headers to compile, which are **not publicly redistributable**.

If the build fails due to `greenworks`, you have two options:

1. **Provide Steamworks SDK headers** — Place them where `node-gyp` can find them, or override the derivation to supply the include path.
2. **Patch out greenworks** — If you don't need Steam Workshop integration features, you can fork the upstream and remove the `greenworks` dependency, then point this flake at your fork.

### Hash placeholders

The `flake.nix` contains placeholder hashes (`sha256-AAA...`). On your first `nix build`, Nix will fail and print the correct hash. Replace the placeholders:

- `src.hash` — hash of the fetched source
- `npmDepsHash` — hash of the npm dependency cache

This is standard practice for Nix packaging and only needs to be done once per version bump.

### Electron version

The flake pins `electron_33`. If the upstream project changes its Electron version, update the `electron` variable in `flake.nix`.

## Updating

To update to a new upstream version:

1. Change `version` in `flake.nix`
2. Clear `src.hash` (set to `""` or `lib.fakeHash`)
3. Clear `npmDepsHash`
4. Run `nix build` — it will fail with the correct hashes
5. Update both hashes and rebuild

## Credits

- Upstream: [FLSoz/terratech-steam-mod-manager](https://github.com/FLSoz/terratech-steam-mod-loader)
