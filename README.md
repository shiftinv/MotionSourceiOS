# MotionSourceiOS
iOS App to provide gyroscope data to Cemu

---

# Installation

1. Jailbroken
   * Install the ipa via *Filza* or *iFile*
2. Non-Jailbroken
   * Take a look over at /r/sideloaded (specifically, [this wiki page](https://www.reddit.com/r/sideloaded/wiki/ipasigning)) on how to use *Cydia Impactor* to install ipas to your device (This also works with a non-paid developer account, which means that everyone can use it)
   * (**tl;dr** download & open *Cydia Impactor* on your preferred desktop operating system, drag-n-drop the ipa onto the window, input your Apple ID and password, wait a few seconds, and... well, that's it)

# Setup

1. Install [Cemuhook](https://sshnuke.net/cemuhook/) if you haven't already
2. Add `serverIP = [YOUR IOS DEVICE'S IP HERE]` under the [Input] section of *cemuhook.ini* (This file is located in Cemu's main directory)
   * *Optional: If you changed the port in the app, add `serverPort = [YOUR PORT]` below the previously added line*
3. Save + close cemuhook.ini, start up Cemu
4. Go to `Options` -> `GamePad motion source` -> `DSU1: BTH DS4 12:AB:34:CD:56:EF`, choose `By Slot`
   * *If you instead see `DSU1: DISCONNECTED`, check your configuration and make sure that your computer and phone are on the same network*
