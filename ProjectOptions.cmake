include(cmake/SystemLink.cmake)
include(cmake/LibFuzzer.cmake)
include(CMakeDependentOption)
include(CheckCXXCompilerFlag)


macro(Explore_supports_sanitizers)
  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND NOT WIN32)
    set(SUPPORTS_UBSAN ON)
  else()
    set(SUPPORTS_UBSAN OFF)
  endif()

  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND WIN32)
    set(SUPPORTS_ASAN OFF)
  else()
    set(SUPPORTS_ASAN ON)
  endif()
endmacro()

macro(Explore_setup_options)
  option(Explore_ENABLE_HARDENING "Enable hardening" ON)
  option(Explore_ENABLE_COVERAGE "Enable coverage reporting" OFF)
  cmake_dependent_option(
    Explore_ENABLE_GLOBAL_HARDENING
    "Attempt to push hardening options to built dependencies"
    ON
    Explore_ENABLE_HARDENING
    OFF)

  Explore_supports_sanitizers()

  if(NOT PROJECT_IS_TOP_LEVEL OR Explore_PACKAGING_MAINTAINER_MODE)
    option(Explore_ENABLE_IPO "Enable IPO/LTO" OFF)
    option(Explore_WARNINGS_AS_ERRORS "Treat Warnings As Errors" OFF)
    option(Explore_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(Explore_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" OFF)
    option(Explore_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(Explore_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" OFF)
    option(Explore_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(Explore_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(Explore_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(Explore_ENABLE_CLANG_TIDY "Enable clang-tidy" OFF)
    option(Explore_ENABLE_CPPCHECK "Enable cpp-check analysis" OFF)
    option(Explore_ENABLE_PCH "Enable precompiled headers" OFF)
    option(Explore_ENABLE_CACHE "Enable ccache" OFF)
  else()
    option(Explore_ENABLE_IPO "Enable IPO/LTO" ON)
    option(Explore_WARNINGS_AS_ERRORS "Treat Warnings As Errors" ON)
    option(Explore_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(Explore_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" ${SUPPORTS_ASAN})
    option(Explore_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(Explore_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" ${SUPPORTS_UBSAN})
    option(Explore_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(Explore_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(Explore_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(Explore_ENABLE_CLANG_TIDY "Enable clang-tidy" ON)
    option(Explore_ENABLE_CPPCHECK "Enable cpp-check analysis" ON)
    option(Explore_ENABLE_PCH "Enable precompiled headers" OFF)
    option(Explore_ENABLE_CACHE "Enable ccache" ON)
  endif()

  if(NOT PROJECT_IS_TOP_LEVEL)
    mark_as_advanced(
      Explore_ENABLE_IPO
      Explore_WARNINGS_AS_ERRORS
      Explore_ENABLE_USER_LINKER
      Explore_ENABLE_SANITIZER_ADDRESS
      Explore_ENABLE_SANITIZER_LEAK
      Explore_ENABLE_SANITIZER_UNDEFINED
      Explore_ENABLE_SANITIZER_THREAD
      Explore_ENABLE_SANITIZER_MEMORY
      Explore_ENABLE_UNITY_BUILD
      Explore_ENABLE_CLANG_TIDY
      Explore_ENABLE_CPPCHECK
      Explore_ENABLE_COVERAGE
      Explore_ENABLE_PCH
      Explore_ENABLE_CACHE)
  endif()

  Explore_check_libfuzzer_support(LIBFUZZER_SUPPORTED)
  if(LIBFUZZER_SUPPORTED AND (Explore_ENABLE_SANITIZER_ADDRESS OR Explore_ENABLE_SANITIZER_THREAD OR Explore_ENABLE_SANITIZER_UNDEFINED))
    set(DEFAULT_FUZZER ON)
  else()
    set(DEFAULT_FUZZER OFF)
  endif()

  option(Explore_BUILD_FUZZ_TESTS "Enable fuzz testing executable" ${DEFAULT_FUZZER})

endmacro()

macro(Explore_global_options)
  if(Explore_ENABLE_IPO)
    include(cmake/InterproceduralOptimization.cmake)
    Explore_enable_ipo()
  endif()

  Explore_supports_sanitizers()

  if(Explore_ENABLE_HARDENING AND Explore_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR Explore_ENABLE_SANITIZER_UNDEFINED
       OR Explore_ENABLE_SANITIZER_ADDRESS
       OR Explore_ENABLE_SANITIZER_THREAD
       OR Explore_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    message("${Explore_ENABLE_HARDENING} ${ENABLE_UBSAN_MINIMAL_RUNTIME} ${Explore_ENABLE_SANITIZER_UNDEFINED}")
    Explore_enable_hardening(Explore_options ON ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()
endmacro()

macro(Explore_local_options)
  if(PROJECT_IS_TOP_LEVEL)
    include(cmake/StandardProjectSettings.cmake)
  endif()

  add_library(Explore_warnings INTERFACE)
  add_library(Explore_options INTERFACE)

  include(cmake/CompilerWarnings.cmake)
  Explore_set_project_warnings(
    Explore_warnings
    ${Explore_WARNINGS_AS_ERRORS}
    ""
    ""
    ""
    "")

  if(Explore_ENABLE_USER_LINKER)
    include(cmake/Linker.cmake)
    configure_linker(Explore_options)
  endif()

  include(cmake/Sanitizers.cmake)
  Explore_enable_sanitizers(
    Explore_options
    ${Explore_ENABLE_SANITIZER_ADDRESS}
    ${Explore_ENABLE_SANITIZER_LEAK}
    ${Explore_ENABLE_SANITIZER_UNDEFINED}
    ${Explore_ENABLE_SANITIZER_THREAD}
    ${Explore_ENABLE_SANITIZER_MEMORY})

  set_target_properties(Explore_options PROPERTIES UNITY_BUILD ${Explore_ENABLE_UNITY_BUILD})

  if(Explore_ENABLE_PCH)
    target_precompile_headers(
      Explore_options
      INTERFACE
      <vector>
      <string>
      <utility>)
  endif()

  if(Explore_ENABLE_CACHE)
    include(cmake/Cache.cmake)
    Explore_enable_cache()
  endif()

  include(cmake/StaticAnalyzers.cmake)
  if(Explore_ENABLE_CLANG_TIDY)
    Explore_enable_clang_tidy(Explore_options ${Explore_WARNINGS_AS_ERRORS})
  endif()

  if(Explore_ENABLE_CPPCHECK)
    Explore_enable_cppcheck(${Explore_WARNINGS_AS_ERRORS} "" # override cppcheck options
    )
  endif()

  if(Explore_ENABLE_COVERAGE)
    include(cmake/Tests.cmake)
    Explore_enable_coverage(Explore_options)
  endif()

  if(Explore_WARNINGS_AS_ERRORS)
    check_cxx_compiler_flag("-Wl,--fatal-warnings" LINKER_FATAL_WARNINGS)
    if(LINKER_FATAL_WARNINGS)
      # This is not working consistently, so disabling for now
      # target_link_options(Explore_options INTERFACE -Wl,--fatal-warnings)
    endif()
  endif()

  if(Explore_ENABLE_HARDENING AND NOT Explore_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR Explore_ENABLE_SANITIZER_UNDEFINED
       OR Explore_ENABLE_SANITIZER_ADDRESS
       OR Explore_ENABLE_SANITIZER_THREAD
       OR Explore_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    Explore_enable_hardening(Explore_options OFF ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()

endmacro()
