extern crate cbindgen;

use std::{env, fs};

fn main() {
    let crate_dir = env::var("CARGO_MANIFEST_DIR").unwrap();

    // 确保目录存在
    fs::create_dir_all("include").expect("Unable to create include directory");

    // 生成C绑定
    cbindgen::Builder::new()
        .with_language(cbindgen::Language::C)
        .with_crate(&crate_dir)
        .generate()
        .expect("Unable to generate bindings")
        .write_to_file("include/bindings.h");

    // 生成C++绑定
    cbindgen::Builder::new()
        .with_language(cbindgen::Language::Cxx)
        .with_crate(&crate_dir)
        .generate()
        .expect("Unable to generate bindings")
        .write_to_file("include/bindings.hpp");
}
