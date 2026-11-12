#!/usr/bin/env bash
# Compiles Core/ with Tests/main.swift and runs it: the stage logic through a whole discharge, no battery needed.
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build
swiftc -swift-version 5 Core/*.swift Tests/main.swift -o build/core-tests
build/core-tests
