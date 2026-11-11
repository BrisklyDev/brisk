use aes::cipher::{BlockDecryptMut, KeyIvInit, block_padding::Pkcs7};

type Aes128CbcDec = cbc::Decryptor<aes::Aes128>;

/// The IV used when `#EXT-X-KEY` has no IV attribute: the media sequence number as a
/// big-endian 128-bit integer.
pub fn implicit_iv(sequence: u64) -> [u8; 16] {
    let mut iv = [0u8; 16];
    iv[8..].copy_from_slice(&sequence.to_be_bytes());
    iv
}

/// Decrypts `data` in place and returns the length of the plaintext
pub fn decrypt_aes128(data: &mut [u8], key: &[u8; 16], iv: &[u8; 16]) -> anyhow::Result<usize> {
    let plain = Aes128CbcDec::new(key.into(), iv.into())
        .decrypt_padded_mut::<Pkcs7>(data)
        .map_err(|_| anyhow::anyhow!("Failed to decrypt segment (wrong key or corrupted data)"))?;
    Ok(plain.len())
}

#[cfg(test)]
mod tests {
    use super::*;
    use aes::cipher::BlockEncryptMut;

    type Aes128CbcEnc = cbc::Encryptor<aes::Aes128>;

    #[test]
    fn decrypts_what_was_encrypted() {
        let key = [7u8; 16];
        let iv = implicit_iv(42);
        let plain = b"hello hls segment, longer than one block".to_vec();
        let mut buf = vec![0u8; plain.len() + 16];
        buf[..plain.len()].copy_from_slice(&plain);
        let encrypted_len = Aes128CbcEnc::new((&key).into(), (&iv).into())
            .encrypt_padded_mut::<Pkcs7>(&mut buf, plain.len())
            .unwrap()
            .len();
        buf.truncate(encrypted_len);
        let len = decrypt_aes128(&mut buf, &key, &iv).unwrap();
        assert_eq!(&buf[..len], &plain[..]);
    }

    #[test]
    fn implicit_iv_is_big_endian_sequence() {
        let iv = implicit_iv(0x0102);
        assert_eq!(&iv[..14], &[0u8; 14]);
        assert_eq!(&iv[14..], &[1, 2]);
    }
}
