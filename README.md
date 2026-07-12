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
