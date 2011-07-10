#!/bin/bash

# build release
rm -rf build/Release
xcodebuild

# move into place
rm -rf /Applications/gfxCardStatus.app
cp -r build/Release/gfxCardStatus.app /Applications/
