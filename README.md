# FnMacTweak

⚡️ A lightweight **Theos Tweak** for Fortnite iOS on Mac, providing several quality-of-life features.

## Features
- **Pointer Control**
    - Toggle mouse visibility with the `Left Option` key.
    - Allow interacting with the mobile UI normally.
- **FPS Unlocking**
    - Unlock 120 FPS (requires 120Hz+ display to work).
    - *Note: Selecting 120 FPS will limit graphical quality to Medium.*
- **Graphics Quality Selection**
    - Unlocks all graphical presets (Low, Medium, High, Epic).
- **Custom options menu**
    - Toggle with the `P` key.
    - Configure mouse sensitivity and custom data location (through the menu).

## Releases
The latest builds can be found in [Releases](https://github.com/rt-someone/FnMacTweak/releases/)

Alternatively, you can download Fortnite with the tweak already included through [FnMacAssistant](https://github.com/isacucho/FnMacAssistant)

## Building

> [!NOTE]
> This guide assumes you already have Theos set up; if not, please refer to [Theos MacOS Installation Guide](https://theos.dev/docs/installation-macos)

1. Clone the repo
2. Build the package:
    ```sh
    make package
    ```
3. Find the compiled `.deb` in the `./packages` directory.

## Credits
Developed by: @rt2746

- [Fishhook](https://github.com/facebook/fishhook) - Used as an alternative to %hookf hooking in a jailed environment
- [PlayTools](https://github.com/PlayCover/PlayTools) - For the device model spoofing code

## Disclaimer
Use at your own risk. Although unlikely, it *is* in fact still possible to get banned because of this tweak. I am **not** responsible for anything that goes wrong.
