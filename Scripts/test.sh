#!/bin/sh

set -eu

developer_dir="$(xcode-select -p 2>/dev/null || true)"
testing_frameworks="$developer_dir/Library/Developer/Frameworks"
testing_plugin="$developer_dir/usr/lib/swift/host/plugins/testing/libTestingMacros.dylib"
testing_support="$developer_dir/Library/Developer/usr/lib"

if [ -d "$testing_frameworks/Testing.framework" ] && [ -f "$testing_plugin" ]; then
    exec swift test \
        -Xswiftc -F \
        -Xswiftc "$testing_frameworks" \
        -Xswiftc -load-plugin-library \
        -Xswiftc "$testing_plugin" \
        -Xlinker -F \
        -Xlinker "$testing_frameworks" \
        -Xlinker -rpath \
        -Xlinker "$testing_frameworks" \
        -Xlinker -rpath \
        -Xlinker "$testing_support" \
        "$@"
fi

exec swift test "$@"
