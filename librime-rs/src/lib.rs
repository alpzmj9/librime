#[cxx::bridge(namespace = "rime::rust")]
pub mod ffi {
    extern "Rust" {
        fn librime_rs_init();
        fn librime_rs_test_log(message: &str);
    }
}

pub fn librime_rs_init() {
    // We will initialize the rust logger here later
    println!("librime-rs initialized!");
}

pub fn librime_rs_test_log(message: &str) {
    println!("librime-rs log: {}", message);
}
