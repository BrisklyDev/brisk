[![license](https://img.shields.io/github/license/AminBhst/brisk?style=flat-square)](https://github.com/AminBhst/brisk/blob/main/LICENSE)
![GitHub Downloads (all assets, all releases)](https://img.shields.io/github/downloads/AminBhst/brisk/total?style=flat-square)
<a href="https://discord.gg/hGBDWNDHG3"><img alt="Discord Chat" src="https://img.shields.io/discord/1298990692000989225?color=5865F2&label=discord&style=flat-square"></a>
[![Telegram Channel](https://img.shields.io/badge/Channel-Telegram-blue.svg?logo=telegram&style=flat-square)](https://t.me/ryedev)

[//]: # (![Static Badge]&#40;https://img.shields.io/badge/Channel-Youtube-red?style=flat-square&logo=youtube&link=https%3A%2F%2Fwww.youtube.com%2F%40ryedev&#41;)
![brisk-header](https://raw.githubusercontent.com/BrisklyDev/brisk/refs/heads/main/assets/brisk-header.png)


## :package: Installation

To install the browser extension, please refer to the [brisk-browser-extension repository](https://github.com/AminBhst/brisk-browser-extension).

<table>
  <tr>
    <th>Platform</th>
    <th>Package/Installation Method</th>
  </tr>
  <tr>
    <td>Windows (x86_64)</td>
    <td>
      <a href="https://github.com/BrisklyDev/brisk/releases/latest">
        <img width="220" alt="Windows Download" src="https://github.com/BrisklyDev/brisk/blob/main/images/windows-download.png?raw=true">
      </a>
  </tr>
  <tr>
    <td>MacOS (x86_64, arm64)</td>
    <td>
      <a href="https://github.com/BrisklyDev/brisk/releases/latest">
        <img width="220" alt="MacOS Download" src="https://github.com/BrisklyDev/brisk/blob/main/images/macos-download.png?raw=true">
      </a>
    </td>
  </tr>
  <tr>
    <td>Flatpak (x86_64, aarch64)</td>
    <td>
      <a href="https://flathub.org/apps/io.github.BrisklyDev.Brisk">
        <img width="220" alt="Download on Flathub" src="https://github.com/BrisklyDev/brisk/blob/main/images/flathub-download.png?raw=true">
      </a>
    </td>
  </tr>
    <tr>
    <td>Snap (amd64)</td>
    <td>
      <a href="https://snapcraft.io/brisk">
        <img width="220" alt="Download on Snap Store" src="https://github.com/BrisklyDev/brisk/blob/main/images/download-snap.png?raw=true">
      </a>
    </td>
  </tr>
  <tr>
    <td>Arch (x86_64)</td>
    <td>
      <a href="https://aur.archlinux.org/packages/brisk">
        <img width="220" alt="Download on AUR" src="https://github.com/BrisklyDev/brisk/blob/main/images/download-aur.png?raw=true">
      </a>
    </td>
  </tr>
  <tr>
    <td>Linux (x86_64)</td>
    <td>
      <a href="https://github.com/BrisklyDev/brisk/releases/latest">
        <img width="220" alt="Tarball Download" src="https://github.com/BrisklyDev/brisk/blob/main/images/download-linux.png?raw=true">
      </a>
    </td>
  </tr>
</table>

> [!IMPORTANT]
> For Linux, make sure to check the [Linux Prerequisites](#key-linux-prerequisites) (for tarball only)
> 
> On Windows, if you encountered a "Windows Protected your PC" warning, click `more info -> run anyway`
>
> For the browser extension to work properly, disable other download manager extensions.

## :rocket: Key Features

- [Powerful Download Engine](#gear-brisks-download-engine)
- [Browser Integration](#globe_with_meridians-browser-integration)
- Downloading video streams from the browser with soft-subbing support
- Download Queues and Scheduling
- Custom Hotkey to add a download URL from the clipboard

## :gear: Brisk's Download Engine
Brisk is powered by a custom-built, high-performance engine that delivers the maximum download speed throughout the entire download process. The engine is built entirely from scratch only using Dart's [http](https://github.com/dart-lang/http), without relying on external libraries or download utilities like aria2.

The key features of the engine include:
- **Dynamic Connection Spawn:** Downloads starts with a single connection and as they progress, new connections are added on the fly. This ensures that a higher number of connections are used only when necessary.
- **Dynamic Connection Reuse:** After a connection completes receiving its designated byte range, it is immediately reassigned to assist another connection. As a result, the engine maintains as many active connections as possible, ensuring that download speeds remain consistently at their peak.
- **Downloading M3U8 Streams:** Brisk is able to capture and download M3U8 video streams from the browser (requires Brisk Browser Extension)
- **Automatic connection reset:** Hanging connections will be reset automatically.

## :globe_with_meridians: Browser Integration
Brisk offers a dedicated browser extension with the following features:
- Capturing download requests from the browser and directly adding them to Brisk
- Extracting all download links from a selected text area and adding them to Brisk all at once
- Capturing m3u8 video streams from the browser

Please refer to the [brisk-browser-extension repository](https://github.com/AminBhst/brisk-browser-extension) for installation. 

## :film_projector: Demo With Browser Integration


https://github.com/user-attachments/assets/844c89a4-8aaa-49f0-9a4e-17fb8614bbc8




## :key: Linux Prerequisites

  - **keybinder-3**
     - Debian/Ubuntu : ```libkeybinder-3.0-0```
     - Fedora/RHEL/CentOS : ```keybinder3```
     - Arch Linux : ```libkeybinder3```

  - **appindicator3-0.1**
     - Debian/Ubuntu : ```libayatana-appindicator3-dev```
     - Fedora/RHEL/CentOS : ```libayatana-appindicator-gtk3```
     - Arch Linux : ```libappindicator-gtk3```


## :hammer_and_wrench: Build From Source

Install the Flutter SDK v3.32.0

```bash
flutter build macos|windows|linux
```

## :heart: Credits and Contributors
Contributions are welcome and appreciated.

<a href="https://github.com/BrisklyDev/Brisk/graphs/contributors">
  <img src="https://contrib.rocks/image?repo=BrisklyDev/Brisk" />
</a>


## :busts_in_silhouette: Community

  <div><a href="https://discord.gg/hGBDWNDHG3"><img src="https://discord.com/api/guilds/1298990692000989225/widget.png?style=banner2" alt="cord.nvim"/></a></div>

