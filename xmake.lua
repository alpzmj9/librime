-- xmake.lua — librime build orchestrator (Windows)
-- Replaces: build.bat
-- Behavior: identical to the original batch script; delegates all actual
--            compilation to CMake. xmake is used only for task / option
--            management and subprocess dispatch.
--
-- Usage examples (mirrors the original batch-script arguments):
--   xmake                          -- build librime (default)
--   xmake run build clean          -- clean all build artefacts
--   xmake run build deps           -- build third-party dependencies
--   xmake run build librime        -- build librime only
--   xmake run build static         -- build as static library
--   xmake run build shared         -- build as shared library (default)
--   xmake run build test           -- build + run tests
--   xmake run build debug          -- debug configuration
--   xmake run build release        -- release configuration (default)
--   xmake run build logging        -- enable glog logging (default)
--   xmake run build nologging      -- disable glog logging
--   xmake run build deps librime   -- build deps then librime
-- Multiple keywords may be combined freely, exactly like the batch script.

-- ---------------------------------------------------------------------------
-- Helper: run a command and abort on failure
-- ---------------------------------------------------------------------------
local function exec(cmd)
    print("[exec] " .. cmd)
    local ok = os.exec(cmd)
    if not ok then
        raise("Command failed: " .. cmd)
    end
end

-- ---------------------------------------------------------------------------
-- Helper: cmake configure + build + install for a single dependency
-- ---------------------------------------------------------------------------
local function build_dep(name, dep_src_dir, build_dir, cmake_flags, build_config)
    print("\nbuilding " .. name .. ".")
    local src  = path.join(dep_src_dir)
    local bdir = path.join(src, build_dir)
    exec(format("cmake %s -B%s %s", src, bdir, cmake_flags))
    exec(format("cmake --build %s --config %s --target install", bdir, build_config))
end

-- ---------------------------------------------------------------------------
-- Main build task
-- ---------------------------------------------------------------------------
task("build")
    set_menu {
        usage = "xmake run build [options...]",
        description = "Orchestrate librime CMake build (mirrors build.bat)",
        options = {
            -- positional-style keyword arguments, passed as plain values
            { nil, "args", "vs", nil, "Build keywords: clean deps librime static shared test debug release logging nologging" }
        }
    }

    on_run(function (...)
        -- ----------------------------------------------------------------
        -- 1. Read environment / configuration (mirrors env.bat logic)
        -- ----------------------------------------------------------------
        local rime_root = os.getenv("RIME_ROOT") or os.curdir()
        print("RIME_ROOT=" .. rime_root)

        local boost_root = os.getenv("BOOST_ROOT")
        if not boost_root or not os.isdir(path.join(boost_root, "boost")) then
            raise("Error: Boost not found! Please set BOOST_ROOT in your environment.")
        end
        print("BOOST_ROOT=" .. boost_root)

        local deps_install_prefix = os.getenv("DEPS_INSTALL_PREFIX") or rime_root
        local rime_install_prefix  = os.getenv("RIME_INSTALL_PREFIX")
                                     or path.join(rime_root, "dist")

        -- Optional CMake generator / arch / toolset overrides
        local cmake_generator   = os.getenv("CMAKE_GENERATOR")
        local arch              = os.getenv("ARCH")
        local platform_toolset  = os.getenv("PLATFORM_TOOLSET")

        -- ----------------------------------------------------------------
        -- 2. Parse keyword arguments (mirrors :parse_cmdline_options loop)
        -- ----------------------------------------------------------------
        local keywords = table.pack(...)  -- xmake passes extra args here

        local do_clean        = false
        local do_build_deps   = false
        local do_build_librime = false
        local build_shared    = "ON"
        local build_test      = "OFF"
        local build_config    = "Release"
        local build_dir       = nil          -- resolved later
        local enable_logging  = "ON"

        for _, kw in ipairs(keywords) do
            kw = tostring(kw):lower()
            if     kw == "clean"     then do_clean         = true
            elseif kw == "deps"      then do_build_deps    = true
            elseif kw == "thirdparty"then do_build_deps    = true  -- deprecated alias
            elseif kw == "librime"   then do_build_librime  = true
            elseif kw == "static"    then build_shared      = "OFF"
            elseif kw == "shared"    then build_shared      = "ON"
            elseif kw == "test"      then
                do_build_librime = true
                build_test       = "ON"
            elseif kw == "debug"     then
                if not build_dir then build_dir = "debug" end
                build_config = "Debug"
            elseif kw == "release"   then
                if not build_dir then build_dir = "build" end
                build_config = "Release"
            elseif kw == "logging"   then enable_logging = "ON"
            elseif kw == "nologging" then enable_logging = "OFF"
            end
        end

        -- Default: build librime when nothing specific was requested
        if not do_clean and not do_build_librime and not do_build_deps then
            do_build_librime = true
        end

        if not build_dir then build_dir = "build" end

        -- ----------------------------------------------------------------
        -- 3. Clean (mirrors :clean block)
        -- ----------------------------------------------------------------
        if do_clean then
            local function rmdir(d)
                if os.isdir(d) then
                    print("removing " .. d)
                    os.rmdir(d)
                end
            end
            rmdir(path.join(rime_root, build_dir))
            for _, dep in ipairs({"glog","googletest","leveldb","marisa-trie","opencc","yaml-cpp"}) do
                rmdir(path.join(rime_root, "deps", dep, build_dir))
            end
        end

        -- ----------------------------------------------------------------
        -- 4. Assemble common CMake flags (mirrors common_cmake_flags)
        -- ----------------------------------------------------------------
        local gen_flag = cmake_generator  and (" -G" .. cmake_generator) or ""
        local arch_flag = arch            and (" -A" .. arch)            or ""
        local ts_flag   = platform_toolset and (" -T" .. platform_toolset) or ""

        local override_c   = path.join(rime_root, "cmake", "c_flag_overrides.cmake")
        local override_cxx = path.join(rime_root, "cmake", "cxx_flag_overrides.cmake")

        local common_flags = format(
            '%s%s%s'
            .. ' -DCMAKE_CONFIGURATION_TYPES:STRING="%s"'
            .. ' -DCMAKE_BUILD_TYPE:STRING="%s"'
            .. ' -DCMAKE_USER_MAKE_RULES_OVERRIDE:PATH="%s"'
            .. ' -DCMAKE_USER_MAKE_RULES_OVERRIDE_CXX:PATH="%s"'
            .. ' -DCMAKE_EXE_LINKER_FLAGS_INIT:STRING="-llibcmt"'
            .. ' -DCMAKE_MSVC_RUNTIME_LIBRARY="MultiThreaded$<$<CONFIG:Debug>:Debug>"',
            gen_flag, arch_flag, ts_flag,
            build_config, build_config,
            override_c, override_cxx
        )

        local deps_flags = common_flags
            .. format(' -DBUILD_SHARED_LIBS:BOOL=OFF -DCMAKE_INSTALL_PREFIX:PATH="%s"',
                      deps_install_prefix)

        -- ----------------------------------------------------------------
        -- 5. Build dependencies (mirrors :build_deps block)
        -- ----------------------------------------------------------------
        if do_build_deps then
            local deps_root = path.join(rime_root, "deps")

            build_dep("glog", path.join(deps_root, "glog"), build_dir,
                deps_flags .. " -DBUILD_TESTING:BOOL=OFF -DWITH_GFLAGS:BOOL=OFF",
                build_config)

            build_dep("leveldb", path.join(deps_root, "leveldb"), build_dir,
                deps_flags .. " -DLEVELDB_BUILD_BENCHMARKS:BOOL=OFF -DLEVELDB_BUILD_TESTS:BOOL=OFF",
                build_config)

            build_dep("yaml-cpp", path.join(deps_root, "yaml-cpp"), build_dir,
                deps_flags
                .. " -DMSVC_SHARED_RT:BOOL=OFF"
                .. " -DYAML_MSVC_SHARED_RT:BOOL=OFF"
                .. " -DYAML_CPP_BUILD_CONTRIB:BOOL=OFF"
                .. " -DYAML_CPP_BUILD_TESTS:BOOL=OFF"
                .. " -DYAML_CPP_BUILD_TOOLS:BOOL=OFF",
                build_config)

            build_dep("googletest", path.join(deps_root, "googletest"), build_dir,
                deps_flags .. " -DBUILD_GMOCK:BOOL=OFF",
                build_config)

            build_dep("marisa-trie", path.join(deps_root, "marisa-trie"), build_dir,
                deps_flags
                .. " -DCMAKE_POSITION_INDEPENDENT_CODE:BOOL=ON"
                .. " -DBUILD_TESTING:BOOL=OFF"
                .. " -DENABLE_TOOLS:BOOL=OFF",
                build_config)

            build_dep("opencc", path.join(deps_root, "opencc"), build_dir,
                deps_flags .. " -DBUILD_TESTING=OFF",
                build_config)
        end

        -- ----------------------------------------------------------------
        -- 6. Build librime (mirrors :build_librime block)
        -- ----------------------------------------------------------------
        if not do_build_librime then
            return
        end

        local rime_flags = common_flags .. format(
            ' -DBUILD_STATIC=ON'
            .. ' -DBUILD_SHARED_LIBS=%s'
            .. ' -DBUILD_TEST=%s'
            .. ' -DENABLE_LOGGING=%s'
            .. ' -DCMAKE_PREFIX_PATH:PATH="%s"'
            .. ' -DCMAKE_INSTALL_PREFIX:PATH="%s"',
            build_shared, build_test, enable_logging,
            deps_install_prefix, rime_install_prefix
        )

        print("\nbuilding librime.\n")
        local bdir = path.join(rime_root, build_dir)
        exec(format("cmake %s -B%s %s", rime_root, bdir, rime_flags))
        exec(format("cmake --build %s --config %s --target install", bdir, build_config))

        -- ----------------------------------------------------------------
        -- 7. Run tests (mirrors ctest block)
        -- ----------------------------------------------------------------
        if build_test == "ON" then
            local test_dir    = path.join(bdir, "test")
            local rime_dll    = path.join(rime_install_prefix, "lib", "rime.dll")
            -- copy rime.dll into the test dir so the test runner can find it
            os.cp(rime_dll, test_dir)
            exec(format(
                'ctest --test-dir "%s" -C %s --output-on-failure',
                test_dir, build_config))
        end

        print("\nready.\n")
    end)