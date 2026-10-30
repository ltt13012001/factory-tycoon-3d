#!/usr/bin/env bash
# Exports the Web build and packs it for hosting as a claude.ai Artifact:
# the engine gzip-compressed as engine-gz.wasm, the game data as
# game-pck.wasm, and web/index.html as the page (it unpacks both, falls
# back to web/fflate.js on older browsers and offers a light mode).
#   GODOT=/path/to/godot tools/build_web_artifact.sh   -> build/web-artifact/
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
mkdir -p build/web
"$GODOT" --headless --path . --export-release "Web" build/web/index.html
out=build/web-artifact
rm -rf "$out"
mkdir -p "$out"
cp build/web/index.js build/web/index.audio.worklet.js build/web/index.audio.position.worklet.js web/fflate.js "$out/"
gzip -9 -n -c build/web/index.wasm > "$out/engine-gz.wasm"
cp build/web/index.pck "$out/game-pck.wasm"
wasm=$(stat -c %s build/web/index.wasm)
pck=$(stat -c %s build/web/index.pck)
sed -E "s/\"fileSizes\":\{[^}]*\}/\"fileSizes\":{\"index.pck\":$pck,\"index.wasm\":$wasm}/" web/index.html > "$out/index.html"
ls -l "$out"
