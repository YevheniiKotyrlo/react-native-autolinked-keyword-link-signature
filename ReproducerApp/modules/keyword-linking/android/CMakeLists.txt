cmake_minimum_required(VERSION 3.13)

# Autolinking adds this directory to the app's CMake build and links react_codegen_<libraryName> into the app.
add_library(react_codegen_keywordlinking SHARED keyword-linking.cpp)

# The keyword signature, as CMake's documentation recommends.
target_link_libraries(react_codegen_keywordlinking PRIVATE fbjni jsi reactnative)
