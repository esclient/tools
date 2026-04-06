MKDIR := 'mkdir -p'
RM := 'rm -rf build-lint build-test'
DOWN := 'curl -fsSL'
DOWN_OUT := '-o'

# Compiler cache: prefer sccache, fall back to ccache, else empty
CACHE_TOOL := `which sccache 2>/dev/null || which ccache 2>/dev/null || echo ""`

# Parallel jobs for Linux
JOBS := `nproc 2>/dev/null || getconf _NPROCESSORS_ONLN 2>/dev/null || echo 4`
PARALLEL := "-j" + JOBS

clean:
    {{RM}}

fetch-proto:
    {{MKDIR}} "{{TMP_DIR}}"
    {{DOWN}} "https://raw.githubusercontent.com/esclient/protos/{{PROTO_TAG}}/{{PROTO_NAME}}" {{DOWN_OUT}} "{{TMP_DIR}}/{{PROTO_NAME}}"

lint: fetch-proto
    conan install . --output-folder=build-lint --build=missing -c tools.cmake.cmaketoolchain:generator=Ninja
    cmake -S . -B build-lint \
        -G "Ninja" \
        -DCMAKE_TOOLCHAIN_FILE=build-lint/conan_toolchain.cmake \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_EXPORT_COMPILE_COMMANDS=ON \
        -DENABLE_CLANG_TIDY=OFF \
        {{ if CACHE_TOOL != "" { "-DCMAKE_C_COMPILER_LAUNCHER=" + CACHE_TOOL + " \\\n        -DCMAKE_CXX_COMPILER_LAUNCHER=" + CACHE_TOOL } else { "" } }}
    cmake --build build-lint -- {{PARALLEL}}
    run-clang-tidy -p build-lint -header-filter='.*' src/

test: fetch-proto
    conan install . --output-folder=build-test --build=missing -c tools.cmake.cmaketoolchain:generator=Ninja
    cmake -S . -B build-test \
        -G "Ninja" \
        -DCMAKE_TOOLCHAIN_FILE=build-test/conan_toolchain.cmake \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_EXPORT_COMPILE_COMMANDS=ON \
        -DENABLE_COVERAGE=ON \
        {{ if CACHE_TOOL != "" { "-DCMAKE_C_COMPILER_LAUNCHER=" + CACHE_TOOL + " \\\n        -DCMAKE_CXX_COMPILER_LAUNCHER=" + CACHE_TOOL } else { "" } }}
    cmake --build build-test -- {{PARALLEL}}
    cd build-test && ctest --output-on-failure --parallel {{JOBS}}
    cd build-test && gcovr \
        --xml \
        --output ../coverage.xml \
        --root .. \
        --filter '\.\./src/' \
        --exclude '_deps/.*' \
        --exclude '.*generated/.*' \
        .