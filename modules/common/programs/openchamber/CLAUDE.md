# OpenChamber Module

Nix package derivation for **OpenChamber Web**, a browser-based GUI for the OpenCode AI coding agent. The package is built using `buildNpmPackage` from a pre-built tarball published on GitHub releases, so no npm build step runs during the Nix build -- only the native `node-pty` addon is compiled.

## Files

| File | Description |
|---|---|
| `default.nix` | Package derivation. Fetches the upstream tarball, patches in a lockfile, compiles `node-pty`, and installs the pre-built dist/server assets. |
| `package-lock.json` | Generated npm lockfile supplied at build time because the upstream project uses `bun.lock` and the tarball ships without one. Required by `buildNpmPackage` to compute the dependency hash. |

## Notable Configuration Details

- **Source**: GitHub release tarball from `btriapitsyn/openchamber`, pinned at version 1.8.5.
- **Native build dependencies**: `python3`, `pkg-config`, and `node-gyp` are needed to compile `node-pty`.
- **No npm build**: `dontNpmBuild = true` -- the tarball already contains pre-built `dist/` and `server/` directories.
- **Install scripts disabled**: Default npm install scripts are skipped to avoid broken `postinstall` hooks (e.g., from `@ibm/plex`). `node-pty` is rebuilt explicitly in `postInstall`.
- **Platform**: Linux only (`lib.platforms.linux`).
- **License**: MIT.
