#----------------------------------------------------------------
# Generated CMake target import file for configuration "Debug".
#----------------------------------------------------------------

# Commands may need to know the format version.
set(CMAKE_IMPORT_FILE_VERSION 1)

# Import target "bellesip-static" for configuration "Debug"
set_property(TARGET bellesip-static APPEND PROPERTY IMPORTED_CONFIGURATIONS DEBUG)
set_target_properties(bellesip-static PROPERTIES
  IMPORTED_LINK_INTERFACE_LANGUAGES_DEBUG "C"
  IMPORTED_LOCATION_DEBUG "${_IMPORT_PREFIX}/lib/libbellesip.a"
  )

list(APPEND _IMPORT_CHECK_TARGETS bellesip-static )
list(APPEND _IMPORT_CHECK_FILES_FOR_bellesip-static "${_IMPORT_PREFIX}/lib/libbellesip.a" )

# Commands beyond this point should not need to know the version.
set(CMAKE_IMPORT_FILE_VERSION)
