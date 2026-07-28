# PDFium Package Configuration for CMake
#
# To use PDFium in your CMake project:
#
#   1. set the environment variable PDFium_DIR to the folder containing this file.
#   2. in your CMakeLists.txt, add
#       find_package(PDFium)
#   3. then link your executable with PDFium
#       target_link_libraries(my_exe pdfium)

include(FindPackageHandleStandardArgs)

find_path(PDFium_INCLUDE_DIR
    NAMES "fpdfview.h"
    PATHS "${CMAKE_CURRENT_LIST_DIR}"
    PATH_SUFFIXES "include"
    NO_DEFAULT_PATH
)

set(PDFium_VERSION "#VERSION#")

if(WIN32)
  find_file(PDFium_LIBRARY
        NAMES "pdfium.lib"
        PATHS "${CMAKE_CURRENT_LIST_DIR}"
        PATH_SUFFIXES "lib"
        NO_DEFAULT_PATH)

  add_library(pdfium STATIC IMPORTED)
  set_target_properties(pdfium
    PROPERTIES
    IMPORTED_LOCATION             "${PDFium_LIBRARY}"
    INTERFACE_INCLUDE_DIRECTORIES "${PDFium_INCLUDE_DIR};${PDFium_INCLUDE_DIR}/cpp"
    IMPORTED_LINK_INTERFACE_LANGUAGES "CXX"
  )

  find_package_handle_standard_args(PDFium
    REQUIRED_VARS PDFium_LIBRARY PDFium_INCLUDE_DIR
    VERSION_VAR PDFium_VERSION
  )
else()
  find_file(PDFium_LIBRARY
        NAMES "libpdfium.a"
        PATHS "${CMAKE_CURRENT_LIST_DIR}"
        PATH_SUFFIXES "lib"
        NO_DEFAULT_PATH)

  add_library(pdfium STATIC IMPORTED)
  set_target_properties(pdfium
    PROPERTIES
    IMPORTED_LOCATION             "${PDFium_LIBRARY}"
    INTERFACE_INCLUDE_DIRECTORIES "${PDFium_INCLUDE_DIR};${PDFium_INCLUDE_DIR}/cpp"
    IMPORTED_LINK_INTERFACE_LANGUAGES "CXX"
  )

  if(APPLE)
    find_library(PDFium_CORE_FOUNDATION CoreFoundation)
    find_library(PDFium_CORE_GRAPHICS CoreGraphics)
    find_package(ZLIB REQUIRED)
    set_property(TARGET pdfium APPEND PROPERTY INTERFACE_LINK_LIBRARIES
      "${PDFium_CORE_FOUNDATION};${PDFium_CORE_GRAPHICS};ZLIB::ZLIB")
  elseif(UNIX)
    find_package(Threads REQUIRED)
    find_package(ZLIB REQUIRED)
    set_property(TARGET pdfium APPEND PROPERTY INTERFACE_LINK_LIBRARIES
      "Threads::Threads;ZLIB::ZLIB;${CMAKE_DL_LIBS};m")
  endif()

  find_package_handle_standard_args(PDFium
    REQUIRED_VARS PDFium_LIBRARY PDFium_INCLUDE_DIR
    VERSION_VAR PDFium_VERSION
  )
endif()
