# rust.cmake
set(rust_compiler "cargo")
set(rust_target_dir "${PROJECT_SOURCE_DIR}/librime-rs/target")

# 从环境变量获取 ARCH 参数
if(DEFINED ENV{ARCH})
  set(ARCH $ENV{ARCH})
else()
  if(CMAKE_SIZEOF_VOID_P EQUAL 8)
    set(ARCH "x64")
  else()
    set(ARCH "Win32")
  endif()
endif()

# 根据 ARCH 设置 Rust target triple
if(ARCH STREQUAL "x64" OR ARCH STREQUAL "x86_64")
  set(rust_target_triple "x86_64-pc-windows-msvc")
elseif(ARCH STREQUAL "Win32" OR ARCH STREQUAL "x86" OR ARCH STREQUAL "i686")
  set(rust_target_triple "i686-pc-windows-msvc")
elseif(ARCH STREQUAL "ARM64" OR ARCH STREQUAL "arm64")
  set(rust_target_triple "aarch64-pc-windows-msvc")
else()
  message(FATAL_ERROR "Unsupported ARCH: ${ARCH}")
endif()

message(STATUS "Building for architecture: ${ARCH}, Rust target: ${rust_target_triple}")

# 根据构建类型设置库路径
if(CMAKE_BUILD_TYPE STREQUAL "Release" OR CMAKE_BUILD_TYPE STREQUAL "RelWithDebInfo")
  set(rust_build_type "--release")
  set(librime_rs_lib "${rust_target_dir}/${rust_target_triple}/release/librime_rs.lib")
  
  # 关键修改：直接在命令中传递 RUSTFLAGS
  set(rust_flags_env "RUSTFLAGS=-C target-feature=+crt-static")
else()
  set(rust_build_type "")
  set(librime_rs_lib "${rust_target_dir}/${rust_target_triple}/debug/librime_rs.lib")
  set(rust_flags_env "RUSTFLAGS=-C target-feature=+crt-static")
endif()

set(librime_rs_h "${rust_target_dir}/cxxbridge/librime-rs/src/lib.rs.h")
set(librime_rs_cc "${rust_target_dir}/cxxbridge/librime-rs/src/lib.rs.cc")

add_custom_command(
  OUTPUT ${librime_rs_lib} ${librime_rs_h} ${librime_rs_cc}
  COMMAND ${CMAKE_COMMAND} -E env ${rust_flags_env} ${rust_compiler} build ${rust_build_type} --target ${rust_target_triple} --target-dir ${rust_target_dir}
  WORKING_DIRECTORY ${PROJECT_SOURCE_DIR}/librime-rs
  COMMENT "Building librime-rs for ${ARCH} (${rust_target_triple}) with static CRT..."
)

add_custom_target(librime_rs_target ALL DEPENDS ${librime_rs_lib} ${librime_rs_h} ${librime_rs_cc})

# 创建导入的静态库 - 先不设置包含目录
add_library(librime_rs STATIC IMPORTED)
set_target_properties(librime_rs PROPERTIES 
  IMPORTED_LOCATION ${librime_rs_lib}
)

# 关键修改：使用生成器表达式延迟路径检查
set_target_properties(librime_rs PROPERTIES
  INTERFACE_INCLUDE_DIRECTORIES "$<BUILD_INTERFACE:${rust_target_dir}/cxxbridge/librime-rs/src>"
)

# 设置依赖
add_dependencies(librime_rs librime_rs_target)