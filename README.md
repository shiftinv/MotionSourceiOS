# MotionSourceiOS
iOS App providing gyroscope/accelerometer data to various emulators

---

## Installation

Fetch the latest .ipa from the releases section, then install the app through any means available to you:

- Non-Jailbroken
   * Use [AltStore](https://altstore.io/), [Sideloadly](https://sideloadly.io/), or similar
   * **alternatively** (requires a macOS device/VM), see [this r/sideloaded wiki page](https://old.reddit.com/r/sideloaded/wiki/ipasigning) on how to use iOS App Signer to install .ipa files
- Jailbroken
   * Install the .ipa via Filza/iFile/appinst/etc.

## Setup

Specific setup steps highly depend on the emulator being used. In general terms, enter the IP and port shown on your device wherever the emulator's input settings ask for it.
See below for more details for a few common applications.

<details>
<summary>Cemu >= 1.18.0</summary>

1. Navigate to `Options` -> `Input settings`
2. Click `+` next to the `Controller` dropdown, select `API: DSUController`, enter the IP and port, select `Controller: Controller 1`, and click `Add`
3. With the controller selected, click `Settings` below, and enable the `Use motion` checkbox
</details>
<details>

<summary>Cemu < 1.18.0</summary>

1. Install [Cemuhook](https://cemuhook.sshnuke.net/) if you haven't already
2. Add `serverIP = [YOUR IOS DEVICE'S IP HERE]` under the [Input] section of *cemuhook.ini* (this file is located in Cemu's main directory)
   * *Optional: If you changed the port in the app, add `serverPort = [YOUR PORT]` below the previously added line*
3. Save + close cemuhook.ini, start up Cemu
4. Navigate to `Options` -> `GamePad motion source` -> `DSU1: BTH DS4 12:AB:34:CD:56:EF`, choose `By Slot`
   * *If you instead see `DSU1: DISCONNECTED`, check your configuration and make sure that your computer and phone are on the same network*
</details>

<details>
<summary>Yuzu</summary>

1. Navigate to `Emulation` -> `Configure...` -> `Controls`
2. Click `Configure` in the `Motion` section at the bottom, remove the listed server, enter your IP and port, and click `Add Server`
3. With the app running and connected, click `Motion 1` below the shown controller and move your phone a bit to select it for motion controls
</details>

<details>
<summary>Ryujinx</summary>

1. Navigate to `Options` -> `Settings` -> `Input`
2. Click `Configure`, ensure a controller is selected as the input device
3. Enable the `Enable Motion Controls` and `Use CemuHook compatible motion` checkboxes, and enter your IP and port
</details>
