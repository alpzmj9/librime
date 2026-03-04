fn main() {
    cxx_build::bridge("src/lib.rs")
        .compile("librime-rs");

    println!("cargo:rerun-if-changed=src/lib.rs");
}
