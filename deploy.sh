#!/bin/bash

./build_release.sh

# move into place
rm -rf /Applications/gfxCardStatus.app
cp -r build/Release/gfxCardStatus.app /Applications/
