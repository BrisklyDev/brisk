//! Parser for HLS (m3u8) playlists.
//!
//! Supports media playlists (segments, `#EXT-X-KEY`, `#EXT-X-MAP`, `#EXT-X-BYTERANGE`,
//! `#EXT-X-MEDIA-SEQUENCE`) and master playlists (`#EXT-X-STREAM-INF` variants).

use std::collections::HashMap;
use url::Url;

#[derive(Clone, Debug, PartialEq)]
pub enum EncryptionMethod {
    None,
    Aes128,
    /// SAMPLE-AES or any other unsupported method
    Unsupported(String),
}

/// The key in effect for a segment
#[derive(Clone, Debug, PartialEq)]
pub struct KeyInfo {
    pub method: EncryptionMethod,
    /// Absolute url of the key
    pub uri: Option<String>,
    /// Explicit IV. If missing, the IV is derived from the media sequence number.
    pub iv: Option<[u8; 16]>,
}

/// A byte range of a resource (`#EXT-X-BYTERANGE` / `BYTERANGE` attribute)
#[derive(Clone, Debug, PartialEq)]
pub struct SubRange {
    pub offset: u64,
    pub length: u64,
}

impl SubRange {
    pub fn to_header(&self) -> String {
        format!(
            "bytes={}-{}",
            self.offset,
            self.offset + self.length.saturating_sub(1)
        )
    }
}

/// A downloadable part of the stream: the initialization section (fMP4) or a media segment.
#[derive(Clone, Debug)]
pub struct MediaSegment {
    /// Absolute url of the segment
    pub url: String,
    pub duration: f64,
    /// Media sequence number, used to derive the implicit AES-128 IV
    pub sequence: u64,
    pub sub_range: Option<SubRange>,
    pub key: Option<KeyInfo>,
}

#[derive(Clone, Debug)]
pub struct MediaPlaylist {
    /// `#EXT-X-MAP` initialization section (fMP4/CMAF). Assembled before all segments.
    pub init_section: Option<MediaSegment>,
    pub segments: Vec<MediaSegment>,
    pub media_sequence: u64,
}

impl MediaPlaylist {
    pub fn total_duration(&self) -> f64 {
        self.segments.iter().map(|s| s.duration).sum()
    }

    /// Whether the stream uses fMP4 segments instead of MPEG-TS
    pub fn is_fragmented_mp4(&self) -> bool {
        self.init_section.is_some()
    }

    pub fn unsupported_encryption(&self) -> Option<String> {
        self.init_section
            .iter()
            .chain(self.segments.iter())
            .filter_map(|s| s.key.as_ref())
            .find_map(|k| match &k.method {
                EncryptionMethod::Unsupported(m) => Some(m.clone()),
                _ => None,
            })
    }
}

#[derive(Clone, Debug)]
pub struct Variant {
    /// Absolute url of the variant's media playlist
    pub url: String,
    pub bandwidth: u64,
    pub resolution: Option<String>,
}

#[derive(Clone, Debug)]
pub enum Playlist {
    Master(Vec<Variant>),
    Media(MediaPlaylist),
}

impl Playlist {
    /// Parses the playlist `content`. Relative urls are resolved against `base_url`.
    pub fn parse(content: &str, base_url: &str) -> anyhow::Result<Playlist> {
        let base = Url::parse(base_url)
            .map_err(|e| anyhow::anyhow!("Invalid playlist url {}: {}", base_url, e))?;
        let resolve = |reference: &str| -> anyhow::Result<String> {
            Ok(base
                .join(reference.trim())
                .map_err(|e| anyhow::anyhow!("Invalid url {} in playlist: {}", reference, e))?
                .to_string())
        };
        let content = content.trim_start_matches('\u{feff}');
        if !content.trim_start().starts_with("#EXTM3U") {
            anyhow::bail!("Not an m3u8 playlist");
        }

        let mut variants = vec![];
        let mut pending_variant: Option<Variant> = None;
        let mut segments = vec![];
        let mut init_section = None;
        let mut media_sequence = 0u64;
        let mut current_key: Option<KeyInfo> = None;
        let mut pending_duration: Option<f64> = None;
        let mut pending_range: Option<(u64, Option<u64>)> = None;
        // Where the next byte range of each resource starts if the offset is omitted
        let mut next_offsets: HashMap<String, u64> = HashMap::new();

        for line in content.lines() {
            let line = line.trim();
            if line.is_empty() {
                continue;
            }
            if let Some(attrs) = line.strip_prefix("#EXT-X-STREAM-INF:") {
                let attrs = parse_attributes(attrs);
                pending_variant = Some(Variant {
                    url: String::new(),
                    bandwidth: attrs
                        .get("BANDWIDTH")
                        .and_then(|b| b.parse().ok())
                        .unwrap_or(0),
                    resolution: attrs.get("RESOLUTION").cloned(),
                });
            } else if let Some(value) = line.strip_prefix("#EXT-X-MEDIA-SEQUENCE:") {
                media_sequence = value.trim().parse().unwrap_or(0);
            } else if let Some(attrs) = line.strip_prefix("#EXT-X-KEY:") {
                current_key = parse_key(&parse_attributes(attrs), &resolve)?;
            } else if let Some(attrs) = line.strip_prefix("#EXT-X-MAP:") {
                if init_section.is_some() {
                    // Only the first initialization section is supported
                    continue;
                }
                let attrs = parse_attributes(attrs);
                let Some(uri) = attrs.get("URI") else {
                    continue;
                };
                let url = resolve(uri)?;
                let sub_range = attrs
                    .get("BYTERANGE")
                    .and_then(|r| parse_byte_range(r))
                    .map(|(length, offset)| SubRange {
                        offset: offset.unwrap_or(0),
                        length,
                    });
                init_section = Some(MediaSegment {
                    url,
                    duration: 0.0,
                    sequence: 0,
                    sub_range,
                    key: current_key.clone(),
                });
            } else if let Some(value) = line.strip_prefix("#EXTINF:") {
                let duration = value.split(',').next().unwrap_or("").trim();
                pending_duration = Some(duration.parse().unwrap_or(0.0));
            } else if let Some(value) = line.strip_prefix("#EXT-X-BYTERANGE:") {
                pending_range = parse_byte_range(value);
            } else if line.starts_with('#') {
                continue;
            } else if let Some(mut variant) = pending_variant.take() {
                variant.url = resolve(line)?;
                variants.push(variant);
            } else if let Some(duration) = pending_duration.take() {
                let url = resolve(line)?;
                let sub_range = pending_range.take().map(|(length, offset)| {
                    let offset = offset
                        .or_else(|| next_offsets.get(&url).copied())
                        .unwrap_or(0);
                    next_offsets.insert(url.clone(), offset + length);
                    SubRange { offset, length }
                });
                segments.push(MediaSegment {
                    url,
                    duration,
                    sequence: media_sequence + segments.len() as u64,
                    sub_range,
                    key: current_key.clone(),
                });
            }
        }

        if !segments.is_empty() {
            return Ok(Playlist::Media(MediaPlaylist {
                init_section,
                segments,
                media_sequence,
            }));
        }
        if !variants.is_empty() {
            return Ok(Playlist::Master(variants));
        }
        anyhow::bail!("The playlist does not contain any segments")
    }
}

fn parse_key(
    attrs: &HashMap<String, String>,
    resolve: &impl Fn(&str) -> anyhow::Result<String>,
) -> anyhow::Result<Option<KeyInfo>> {
    let method = match attrs.get("METHOD").map(|m| m.as_str()) {
        None | Some("NONE") => return Ok(None),
        Some("AES-128") => EncryptionMethod::Aes128,
        Some(other) => EncryptionMethod::Unsupported(other.to_string()),
    };
    let uri = attrs.get("URI").map(|u| resolve(u)).transpose()?;
    if method == EncryptionMethod::Aes128 && uri.is_none() {
        anyhow::bail!("AES-128 key without URI");
    }
    let iv = attrs.get("IV").map(|iv| parse_iv(iv)).transpose()?;
    Ok(Some(KeyInfo { method, uri, iv }))
}

/// Parses a hexadecimal IV (`0x...`) into 16 bytes, left padded with zeros
fn parse_iv(value: &str) -> anyhow::Result<[u8; 16]> {
    let hex = value
        .trim()
        .trim_start_matches("0x")
        .trim_start_matches("0X");
    if hex.is_empty() || hex.len() > 32 || !hex.chars().all(|c| c.is_ascii_hexdigit()) {
        anyhow::bail!("Invalid IV {}", value);
    }
    let padded = format!("{:0>32}", hex);
    let mut iv = [0u8; 16];
    for (i, byte) in iv.iter_mut().enumerate() {
        *byte = u8::from_str_radix(&padded[i * 2..i * 2 + 2], 16)?;
    }
    Ok(iv)
}

/// Parses `<length>[@<offset>]`
fn parse_byte_range(value: &str) -> Option<(u64, Option<u64>)> {
    let mut parts = value.trim().splitn(2, '@');
    let length = parts.next()?.trim().parse().ok()?;
    let offset = parts.next().and_then(|o| o.trim().parse().ok());
    Some((length, offset))
}

/// Parses an attribute list such as `METHOD=AES-128,URI="key.bin",IV=0x01`
fn parse_attributes(input: &str) -> HashMap<String, String> {
    let mut attrs = HashMap::new();
    let mut rest = input.trim();
    while !rest.is_empty() {
        let Some(eq) = rest.find('=') else {
            break;
        };
        let key = rest[..eq].trim().to_string();
        rest = &rest[eq + 1..];
        let value;
        if let Some(stripped) = rest.strip_prefix('"') {
            let end = stripped.find('"').unwrap_or(stripped.len());
            value = stripped[..end].to_string();
            rest = stripped.get(end + 1..).unwrap_or("");
            rest = rest.trim_start_matches(|c: char| c != ',');
        } else {
            let end = rest.find(',').unwrap_or(rest.len());
            value = rest[..end].trim().to_string();
            rest = &rest[end..];
        }
        rest = rest.strip_prefix(',').unwrap_or(rest).trim_start();
        attrs.insert(key, value);
    }
    attrs
}

#[cfg(test)]
mod tests {
    use super::*;

    const BASE: &str = "https://cdn.example.com/video/index.m3u8";

    #[test]
    fn parses_media_playlist() {
        let content = "#EXTM3U\n#EXT-X-MEDIA-SEQUENCE:10\n\
            #EXT-X-KEY:METHOD=AES-128,URI=\"key.bin\"\n\
            #EXTINF:4.0,\nseg0.ts\n\
            #EXT-X-KEY:METHOD=AES-128,URI=\"/k2\",IV=0x01\n\
            #EXTINF:3.5,title\nhttps://other.com/seg1.ts\n\
            #EXT-X-KEY:METHOD=NONE\n#EXTINF:2,\nseg2.ts\n#EXT-X-ENDLIST\n";
        let Playlist::Media(p) = Playlist::parse(content, BASE).unwrap() else {
            panic!("expected media playlist");
        };
        assert_eq!(p.segments.len(), 3);
        assert_eq!(p.segments[0].url, "https://cdn.example.com/video/seg0.ts");
        assert_eq!(p.segments[0].sequence, 10);
        assert_eq!(
            p.segments[0].key.as_ref().unwrap().uri.as_deref(),
            Some("https://cdn.example.com/video/key.bin")
        );
        assert_eq!(p.segments[1].url, "https://other.com/seg1.ts");
        let key1 = p.segments[1].key.as_ref().unwrap();
        assert_eq!(key1.uri.as_deref(), Some("https://cdn.example.com/k2"));
        assert_eq!(key1.iv.unwrap()[15], 1);
        assert!(p.segments[2].key.is_none());
        assert_eq!(p.total_duration(), 9.5);
    }

    #[test]
    fn parses_master_playlist() {
        let content = "#EXTM3U\n\
            #EXT-X-STREAM-INF:BANDWIDTH=800000,RESOLUTION=640x360,CODECS=\"avc1.4d401e,mp4a.40.2\"\n\
            low/index.m3u8\n\
            #EXT-X-STREAM-INF:BANDWIDTH=2400000,RESOLUTION=1280x720\n\
            high/index.m3u8\n";
        let Playlist::Master(variants) = Playlist::parse(content, BASE).unwrap() else {
            panic!("expected master playlist");
        };
        assert_eq!(variants.len(), 2);
        assert_eq!(variants[1].bandwidth, 2_400_000);
        assert_eq!(variants[0].resolution.as_deref(), Some("640x360"));
        assert_eq!(variants[1].url, "https://cdn.example.com/video/high/index.m3u8");
    }

    #[test]
    fn parses_init_section_and_byte_ranges() {
        let content = "#EXTM3U\n#EXT-X-MAP:URI=\"init.mp4\",BYTERANGE=\"720@0\"\n\
            #EXTINF:4,\n#EXT-X-BYTERANGE:1000@720\nmedia.mp4\n\
            #EXTINF:4,\n#EXT-X-BYTERANGE:500\nmedia.mp4\n";
        let Playlist::Media(p) = Playlist::parse(content, BASE).unwrap() else {
            panic!("expected media playlist");
        };
        assert!(p.is_fragmented_mp4());
        assert_eq!(
            p.init_section.as_ref().unwrap().sub_range,
            Some(SubRange { offset: 0, length: 720 })
        );
        assert_eq!(p.segments[0].sub_range, Some(SubRange { offset: 720, length: 1000 }));
        assert_eq!(p.segments[1].sub_range, Some(SubRange { offset: 1720, length: 500 }));
        assert_eq!(p.segments[1].sub_range.as_ref().unwrap().to_header(), "bytes=1720-2219");
    }

    #[test]
    fn detects_unsupported_encryption() {
        let content = "#EXTM3U\n#EXT-X-KEY:METHOD=SAMPLE-AES,URI=\"k\"\n#EXTINF:4,\ns.ts\n";
        let Playlist::Media(p) = Playlist::parse(content, BASE).unwrap() else {
            panic!("expected media playlist");
        };
        assert_eq!(p.unsupported_encryption().as_deref(), Some("SAMPLE-AES"));
    }

    #[test]
    fn rejects_non_playlists() {
        assert!(Playlist::parse("<html></html>", BASE).is_err());
        assert!(Playlist::parse("#EXTM3U\n#EXT-X-ENDLIST\n", BASE).is_err());
    }
}
