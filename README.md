# OmniRoute Manager & Installer

A lightweight, user-friendly Windows GUI utility and installer wrapper for managing [OmniRoute](https://github.com/diegosouzapw/OmniRoute) (a multi-route cellular network manager).

This utility simplifies running and managing the OmniRoute service on Windows via a custom PowerShell GUI launcher.

## Key Features
- **One-Click Run**: Launch the PowerShell GUI directly using `OmniRoute_Manager.bat`.
- **System Tray/Console Management**: Conveniently start, stop, or configure settings.
- **Port Mapping**: Automatically works with the default OmniRoute dashboard port (`20128`).

## Attribution
This project is an installer and management GUI designed to accompany the core **OmniRoute** application created by [diegosouzapw](https://github.com/diegosouzapw/OmniRoute). 

## License
This project and the core OmniRoute application are licensed under the [MIT License](LICENSE).

## How to Use
1. Clone or download this repository.
2. Run `OmniRoute_Manager.bat` (you may need to run as administrator depending on permissions required for network routing changes).
3. Access the dashboard at `localhost:20128/dashboard/` to configure your API keys.

## Troubleshooting & Tips

### Stale Next.js Build Lock / Startup Crashes (Update Issues)
If you tried to update to version `v3.8.47` or newer and the server failed to start afterwards, it was likely due to a stale Next.js build lock file (`.build/next/lock`) blocking the compilation. This installer has been patched to automatically clear these stale locks before running any new builds.

### Why `npm install -g omniroute` Fails or Warns
If you or your users try to install the core `omniroute` package globally using standard `npm install -g omniroute`, npm 7+ will often fail or print peer dependency conflicts. This happens because the core `omniroute` application uses React 19, while some nested UI dependencies still require React 18.

* **Recommended Solution:** Use this installer (`OmniRoute_Manager.bat`). It utilizes `pnpm` to resolve dependency conflicts cleanly and compiles the standalone production build automatically.
* **NPM Fallback:** If you must use global npm, run:
  ```bash
  npm install -g omniroute --legacy-peer-deps
  ```

