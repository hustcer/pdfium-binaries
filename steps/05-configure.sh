#!/bin/bash -eux

OS=${PDFium_TARGET_OS:?}
SOURCE=${PDFium_SOURCE_DIR:-pdfium}
BUILD=${PDFium_BUILD_DIR:-$SOURCE/out}
TARGET_CPU=${PDFium_TARGET_CPU:?}
TARGET_ENVIRONMENT=${PDFium_TARGET_ENVIRONMENT:-}
ENABLE_V8=${PDFium_ENABLE_V8:-false}
IS_DEBUG=${PDFium_IS_DEBUG:-false}
BUILD_TYPE=${PDFium_BUILD_TYPE:-shared}

mkdir -p "$BUILD"

(
  echo "is_debug = $IS_DEBUG"
  echo "pdf_is_standalone = true"
  echo "pdf_use_partition_alloc = false"
  echo "target_cpu = \"$TARGET_CPU\""
  echo "target_os = \"$OS\""
  echo "pdf_enable_v8 = $ENABLE_V8"
  echo "pdf_enable_xfa = $ENABLE_V8"
  echo "treat_warnings_as_errors = false"
  echo "is_component_build = false"

  if [ "$ENABLE_V8" == "true" ]; then
    echo "v8_use_external_startup_data = false"
    echo "v8_enable_i18n_support = false"
  fi

  if [ "$BUILD_TYPE" == "static" ]; then
    echo "pdf_is_complete_lib = true"
    # Object-level debug info dominates static archive size (mac: ~277 MB vs
    # ~25 MB code-only) and is discarded when consumers link the archive.
    echo "symbol_level = 0"

    # Released desktop archives must use the consumer platform's C++ ABI.
    # Chromium's private libc++ exposes std::__Cr symbols that downstream
    # system linkers cannot resolve, including MSVC consumers on Windows.
    if [ "$OS" == "mac" ] || [ "$OS" == "linux" ] || [ "$OS" == "win" ]; then
      echo "use_custom_libcxx = false"
      echo "use_custom_libcxx_for_host = false"
    fi

    # Keep Chromium's LLD for its hermetic sysroot links, but disable CREL in
    # released Linux archives because the GNU linker used by MoonBit native
    # does not understand that experimental relocation format.
    if [ "$OS" == "linux" ]; then
      echo "pdfium_use_crel = false"
    fi
  fi

  case "$OS" in
    android)
      echo "clang_use_chrome_plugins = false"
      echo "default_min_sdk_version = 23"
      echo "use_mold = false"
      ;;
    ios)
      [ -n "$TARGET_ENVIRONMENT" ] && echo "target_environment = \"$TARGET_ENVIRONMENT\""
      echo "ios_enable_code_signing = false"
      echo "use_blink = true"
      [ "$ENABLE_V8" == "true" ] && [ "$TARGET_CPU" == "arm64" ] && echo 'arm_control_flow_integrity = "none"'
      echo "clang_use_chrome_plugins = false"
      ;;
    linux)
      echo "clang_use_chrome_plugins = false"
      # The MIPS build patch has always disabled CREL for older toolchains,
      # including shared builds. Preserve that behavior through the explicit
      # downstream build argument introduced by patches/linux/build.patch.
      if [ "$BUILD_TYPE" != "static" ] && { [ "$TARGET_CPU" == "mipsel" ] || [ "$TARGET_CPU" == "mips64el" ]; }; then
        echo "pdfium_use_crel = false"
      fi
      # AOTW, //build/config/sysroot.gni lacks handling of ppc64, so we manually set the sysroot to ensure working builds with proper glibc requirement
      if [ "$TARGET_CPU" == "ppc64" ]; then
        echo "use_sysroot = true"
        echo "sysroot = \"//build/linux/debian_bullseye_ppc64el-sysroot\""
      fi
      ;;
    mac)
      echo "clang_use_chrome_plugins = false"
      ;;
    emscripten)
      echo 'pdf_is_complete_lib = true'
      echo 'is_clang = false'
      echo 'use_custom_libcxx = false'
      if [ "$ENABLE_V8" == "true" ]; then
        # Set a toolchain with the same bitness as the target CPU
        echo "v8_snapshot_toolchain = \"//build/toolchain/linux:x86\""
        # Don't try to build libc++ because it requires GCC 14+
        echo 'use_custom_libcxx_for_host = false'
      fi
      ;;
  esac

  case "$TARGET_ENVIRONMENT" in
    musl)
      echo 'is_musl = true'
      echo 'is_clang = false'
      echo 'use_custom_libcxx = false'
      echo 'use_custom_libcxx_for_host = false'
      echo 'use_glib = false'
      [ "$ENABLE_V8" == "true" ] && case "$TARGET_CPU" in
        arm)
            echo "v8_snapshot_toolchain = \"//build/toolchain/linux:clang_x86_v8_arm\""
            ;;
        arm64)
            echo "v8_snapshot_toolchain = \"//build/toolchain/linux:clang_x64_v8_arm64\""
            ;;
        *)
            echo "v8_snapshot_toolchain = \"//build/toolchain/linux:$TARGET_CPU\""
            ;;
      esac
      ;;
  esac

) | sort > "$BUILD/args.gn"

# Generate Ninja files
pushd "$SOURCE"
gn gen "$BUILD"
popd
