#!/bin/bash -eu

this_dir="$(dirname "$0")"
#. "$this_dir/functions.sh"

root_dir="$this_dir/"
source_dir="$root_dir/src"
target_dir="$root_dir/bin"
mkdir -p "$target_dir"
#pdflatex -synctex=1 -interaction=nonstopmode %.tex
pdflatex -synctex=1 -interaction=nonstopmode -output-directory "$target_dir" "$source_dir/cv.tex"
