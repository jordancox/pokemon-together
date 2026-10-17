#!/bin/bash
# On the cloud Mac: puts the Kokoro voice model in ios/build/Kokoro for the app (about 360 MB, never committed). It's
# sherpa-onnx's ready-made Kokoro v1.0 (Apache 2.0): the model, the voices, the sound symbols it reads, and espeak-ng's
# data, which turns words into those sounds. The full model, not the int8 one: on the VM it made speech faster.
set -euo pipefail
cd "$(dirname "$0")/.."
[ -f build/Kokoro/model.onnx ] && exit 0
mkdir -p build && cd build
rm -rf Kokoro kokoro-multi-lang-v1_0
curl -sSfL https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models/kokoro-multi-lang-v1_0.tar.bz2 | tar xj
mkdir Kokoro
mv kokoro-multi-lang-v1_0/{model.onnx,voices.bin,tokens.txt,espeak-ng-data,LICENSE} Kokoro/
rm -rf kokoro-multi-lang-v1_0
du -sh Kokoro
