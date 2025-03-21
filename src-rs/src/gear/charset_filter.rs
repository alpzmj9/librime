use rime::gear::charset_filter;
#[no_mangle]
pub extern "C" fn is_extended_cjk(ch: u32) -> bool {
    charset_filter::is_extended_cjk(ch)
}
