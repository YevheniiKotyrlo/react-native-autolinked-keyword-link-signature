#!/usr/bin/env bash
# Configures ReproducerApp's Android CMake build (arm64-v8a, Debug), which autolinks modules/keyword-linking, a library
# whose CMakeLists links its target with `target_link_libraries(... PRIVATE ...)`.
#   ./reproduce.sh            the react-native version package.json names
#   ./reproduce.sh nightly    react-native@nightly, built from main
# Exit 1 while the configure fails on CMake's all-keyword-or-all-plain error, 0 once it passes, 2 when a step fails
# another way.
set -uo pipefail

version="${1:-}"
here="$(cd "$(dirname "$0")" && pwd)"
app="${here}/ReproducerApp"
logs="${here}/logs"
mkdir -p "${logs}"

if ! node_version="$(node --version)" || ! java_version="$(java -version 2>&1 | head -n 1)"; then
    echo "SUMMARY: node or java is missing"
    exit 2
fi
uname_line="$(uname -mprs)" || exit 2
echo "${uname_line}; node ${node_version}; ${java_version}"

echo "\$ npm install"
if ! (cd "${app}" && npm install --no-audit --no-fund > "${logs}/npm-install.log" 2>&1); then
    tail -n 20 "${logs}/npm-install.log"
    echo "SUMMARY: npm install failed"
    exit 2
fi
if [[ -n "${version}" ]]; then
    # Every @react-native/* package the app names, at the same version, and the CLI that version pairs with.
    if ! names="$(cd "${app}" && node -p 'const p = require("./package.json"); Object.keys({...p.dependencies, ...p.devDependencies}).filter((name) => name.startsWith("@react-native/")).join(" ")')"; then
        echo "SUMMARY: reading ReproducerApp/package.json failed"
        exit 2
    fi
    packages=("react-native@${version}" "@react-native/community-cli-plugin@${version}")
    for name in ${names}; do
        packages+=("${name}@${version}")
    done
    if [[ "${version}" == nightly ]]; then
        packages+=(@react-native-community/cli@next @react-native-community/cli-platform-android@next
            @react-native-community/cli-platform-ios@next)
    fi
    echo "\$ npm install --no-save --legacy-peer-deps ${packages[*]}"
    if ! (cd "${app}" && npm install --no-audit --no-fund --no-save --legacy-peer-deps "${packages[@]}" > "${logs}/npm-install-react-native.log" 2>&1); then
        tail -n 20 "${logs}/npm-install-react-native.log"
        echo "SUMMARY: npm install ${packages[*]} failed"
        exit 2
    fi
fi
react_native_version="$(cd "${app}" && node -p 'require("react-native/package.json").version')" || exit 2
echo "react-native ${react_native_version}"

task='configureCMakeDebug[arm64-v8a]'
echo "\$ ./gradlew :app:${task} -PreactNativeArchitectures=arm64-v8a"
gradle_status=0
(cd "${app}/android" && ./gradlew --no-daemon --console=plain ":app:${task}" -PreactNativeArchitectures=arm64-v8a \
    > "${logs}/configure.log" 2>&1) || gradle_status=$?
echo "gradle exit ${gradle_status}"

if [[ "${gradle_status}" -eq 0 ]]; then
    echo "SUMMARY: the app's CMake build configures with a library that links with the keyword signature (react-native ${react_native_version})"
    exit 0
fi
shown_root="${here}"
if windows_root="$(cd "${here}" && pwd -W 2>/dev/null)"; then
    shown_root="${windows_root}"
fi
cmake_error="$(grep -A 12 'CMake Error at' "${logs}/configure.log" | grep -v '^\s*at ' | sed -e "s#${shown_root}/##g" -e "s#${here}/##g")"
if grep -q 'The keyword signature for target_link_libraries has already been used' "${logs}/configure.log"; then
    printf '%s\n' "${cmake_error}"
    echo "SUMMARY: defect: the app's CMake configure fails, as ReactNative-application.cmake links react_codegen_keywordlinking with the plain signature and its own CMakeLists uses PRIVATE (react-native ${react_native_version})"
    exit 1
fi
tail -n 30 "${logs}/configure.log"
echo "SUMMARY: the configure failed for another reason"
exit 2
