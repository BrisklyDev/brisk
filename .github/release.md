# Changelog

## :sparkles: New Features

- **Kasma Engine (Beta)**: A new, faster download engine written in Rust. Enable it in `Settings → Connection → Download Engine` by selecting **Performance (Beta)**. It supports both regular (HTTP) and video stream (M3U8) downloads. Proxies are not supported by Kasma yet; downloads that use a proxy automatically fall back to the default engine.
- **Speed Limit**: Limit the download speed of each download (Kasma engine only).
  - Set a default limit in `Settings → Connection → Download Engine`, in KB/s or MB/s.
  - Change the limit of a running download on the fly from the new **Speed Limit** tab in the download progress window. A limit set there applies only to that download and overrides the default from the settings.
- **Improved Video Downloads**:
  - Added support for fMP4 (CMAF) streams, used by sites such as x.com.
  - Fixed downloads from CDNs that require the page's Referer or the browser's User-Agent (e.g. TikTok).

## :bug: Bug Fixes

- Fixed multiple exit dialogs stacking when the close button was pressed repeatedly.
- The rhttp client was removed. Existing installations are switched back to the default HTTP client.
