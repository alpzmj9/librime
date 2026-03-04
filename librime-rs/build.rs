fn main() {
    // 构建 C++/Rust 桥接代码
    cxx_build::bridge("src/lib.rs")
        .std("c++17")
        .compile("librime-rs");

    // static_vcruntime 会自动处理运行时库
    static_vcruntime::metabuild();

    // 只在 Windows 上链接系统库
    #[cfg(target_os = "windows")]
    {
        println!("cargo:rustc-link-lib=kernel32");
        println!("cargo:rustc-link-lib=advapi32");
        println!("cargo:rustc-link-lib=ntdll");
        println!("cargo:rustc-link-lib=userenv");
        println!("cargo:rustc-link-lib=ws2_32");
        println!("cargo:rustc-link-lib=dbghelp");  // 从 native-static-libs 看到的
    }

    println!("cargo:rerun-if-changed=src/lib.rs");
}