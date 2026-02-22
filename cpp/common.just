MKDIR := 'mkdir -p'
RM := 'rm -rf build-lint build-test'
DOWN := 'curl -fsSL'
DOWN_OUT := '-o'

clean:
    {{RM}}

fetch-proto:
    {{MKDIR}} "{{TMP_DIR}}"
    {{DOWN}} "https://raw.githubusercontent.com/esclient/protos/{{PROTO_TAG}}/{{PROTO_NAME}}" {{DOWN_OUT}} "{{TMP_DIR}}/{{PROTO_NAME}}"

format:
    cmake --build build-lint --target clang-format
    cmake --build build-lint --target cmake-format

lint: fetch-proto
    conan install . --output-folder=build-lint --build=missing -c tools.cmake.cmaketoolchain:generator=Ninja
    cmake -S . -B build-lint \
        -G "Ninja" \
        -DCMAKE_TOOLCHAIN_FILE=build-lint/conan_toolchain.cmake \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_EXPORT_COMPILE_COMMANDS=ON \
        -DENABLE_CLANG_TIDY=ON
    cmake --build build-lint
    cmake --build build-lint --target lint-all

test: fetch-proto
    conan install . --output-folder=build-test --build=missing -c tools.cmake.cmaketoolchain:generator=Ninja
    cmake -S . -B build-test \
        -G "Ninja" \
        -DCMAKE_TOOLCHAIN_FILE=build-test/conan_toolchain.cmake \
        -DCMAKE_BUILD_TYPE=Debug \
        -DCMAKE_EXPORT_COMPILE_COMMANDS=ON \
        -DENABLE_COVERAGE=ON
    cmake --build build-test
    cd build-test && ctest --output-on-failure
    lcov --capture \
        --directory build-test \
        --output-file coverage.info \
        --ignore-errors mismatch
    lcov --remove coverage.info \
        '/usr/*' \
        '*/conan/*' \
        '*/build-test/*' \
        '*/tests/*' \
        '*/grpc/*' \
        '*/generated/*' \
        --output-file coverage.info

prepare: format lint test
