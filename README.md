# MotionSourceiOS
iOS App providing gyroscope data to Cemu

---

# Installation

1. Jailbroken
   * Install the ipa via *Filza*/*iFile*/*appinst*/etc.
2. Non-Jailbroken (requires a macOS device/VM)
   * Take a look over at /r/sideloaded (specifically, [this wiki page](https://old.reddit.com/r/sideloaded/wiki/ipasigning)) on how to use *iOS App Signer* to install ipas to your device (this also works with a free developer account)

# Setup

1. Install [Cemuhook](https://sshnuke.net/cemuhook/) if you haven't already
2. Add `serverIP = [YOUR IOS DEVICE'S IP HERE]` under the [Input] section of *cemuhook.ini* (This file is located in Cemu's main directory)
   * *Optional: If you changed the port in the app, add `serverPort = [YOUR PORT]` below the previously added line*
3. Save + close cemuhook.ini, start up Cemu
4. Go to `Options` -> `GamePad motion source` -> `DSU1: BTH DS4 12:AB:34:CD:56:EF`, choose `By Slot`
   * *If you instead see `DSU1: DISCONNECTED`, check your configuration and make sure that your computer and phone are on the same network*
