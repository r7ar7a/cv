#!/usr/bin/env bash
set -eu

tex_dir=/tmp/generated
mkdir -p "$tex_dir"

python3 /cv/src/python/generate_from_templates.py /cv/src/template/ "$tex_dir" "$1" && /cv/src/bash/build.sh "$tex_dir"

