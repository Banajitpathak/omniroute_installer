# OmniRoute Manager & Installer

A lightweight, user-friendly Windows GUI utility and installer wrapper for managing [OmniRoute](https://github.com/diegosouzapw/OmniRoute) (a local, unified AI gateway connecting coding agents and editors to 230+ AI providers via a single OpenAI-compatible endpoint).

This utility simplifies running and managing the OmniRoute service on Windows via a custom PowerShell GUI launcher.

## Key Features
![OmniRoute Manager GUI](https://github.com/user-attachments/assets/bf0efbe2-889d-4b4e-ab23-ac251c36ae0c)

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

### Smart Installation Method
The installer automatically utilizes a dual-path installation workflow to ensure maximum reliability and speed:
1. **Primary (NPM Global)**: Installs the official prebuilt `omniroute` package globally using `--legacy-peer-deps` to bypass React 18/19 peer dependency conflicts. This takes under 30 seconds and requires no local building.
2. **Secondary Fallback (Shallow Clone)**: If the NPM registry is unreachable or fails, the installer automatically falls back to cloning the repository with a shallow clone (`--depth 1`) and building it locally using `pnpm` and Node.js.

## Contributing

Contributions are welcome! If you would like to help improve the Windows Installer/Manager:
1. **Report Bugs or Propose Features**: Open a topic in the [Issues](https://github.com/Banajitpathak/omniroute_installer/issues) or [Discussions](https://github.com/Banajitpathak/omniroute_installer/discussions) section.
2. **Submit Code Changes**:
   - Fork the repository.
   - Create a branch for your feature or fix.
   - Commit your changes and verify that the PowerShell script parses cleanly.
   - Open a Pull Request (PR) back to the `main` branch.


