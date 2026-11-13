# An autolinked library that links with `target_link_libraries(... PRIVATE ...)` fails the app's CMake configure

Made from React Native's reproducer template. `ReproducerApp` is the template's app with one local library added as a dependency, `modules/keyword-linking`, whose `react-native.config.js` gives Android a `libraryName` and a `cmakeListsPath`, and whose `android/CMakeLists.txt` links its target with the keyword signature:

```cmake
add_library(react_codegen_keywordlinking SHARED keyword-linking.cpp)
target_link_libraries(react_codegen_keywordlinking PRIVATE fbjni jsi reactnative)
```

```sh
./reproduce.sh            # the react-native version ReproducerApp/package.json names
./reproduce.sh nightly    # react-native@nightly, built from main
```

It needs Node, a JDK and the Android SDK with the NDK the template names. It runs `npm install` in `ReproducerApp`, then `./gradlew :app:configureCMakeDebug[arm64-v8a]`, and prints the CMake error.

It exits 1 while the configure fails because `ReactNative-application.cmake` links `react_codegen_keywordlinking` to `common_flags` with the plain signature, 0 once the configure passes, and 2 when a step fails another way. With the library's `PRIVATE` removed, the configure passes.
