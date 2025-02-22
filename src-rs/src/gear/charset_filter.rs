#[no_mangle]
pub extern "C" fn is_extended_cjk(ch: u32) -> bool {
    (0x3400..=0x4DBF).contains(&ch) ||     // CJK Unified Ideographs Extension A
    (0x20000..=0x2A6DF).contains(&ch) ||   // CJK Unified Ideographs Extension B
    (0x2A700..=0x2B73F).contains(&ch) ||   // CJK Unified Ideographs Extension C
    (0x2B740..=0x2B81F).contains(&ch) ||   // CJK Unified Ideographs Extension D
    (0x2B820..=0x2CEAF).contains(&ch) ||   // CJK Unified Ideographs Extension E
    (0x2CEB0..=0x2EBEF).contains(&ch) ||   // CJK Unified Ideographs Extension F
    (0x30000..=0x3134F).contains(&ch) ||   // CJK Unified Ideographs Extension G
    (0x31350..=0x323AF).contains(&ch) ||   // CJK Unified Ideographs Extension H
    (0x2EBF0..=0x2EE5D).contains(&ch) ||   // CJK Unified Ideographs Extension I
    (0x3300..=0x33FF).contains(&ch) ||     // CJK Compatibility
    (0xFE30..=0xFE4F).contains(&ch) ||     // CJK Compatibility Forms
    (0xF900..=0xFAFF).contains(&ch) ||     // CJK Compatibility Ideographs
    (0x2F800..=0x2FA1F).contains(&ch) // CJK Compatibility Ideographs Supplement
}
