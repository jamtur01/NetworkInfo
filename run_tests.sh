#!/bin/bash

# Script to run NetworkInfo tests

cd /Users/james/src/NetworkInfo

echo "Building NetworkInfo for testing..."
swift build

echo "Running tests..."
swift test -v

# Check test result
if [ $? -eq 0 ]; then
    echo "✅ All tests passed!"
else
    echo "❌ Some tests failed."
fi
