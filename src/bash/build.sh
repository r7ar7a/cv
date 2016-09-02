#!/bin/bash -eu

this_dir="$(dirname "$0")"
. "$this_dir/functions.sh"

root_dir="$this_dir/../../"
source_dir="$root_dir/src"
target_dir="$root_dir/bin"

cat "$source_dir/tex/cv.tex" | sed 's/%%PC_COMMENT%%//g' > "$source_dir/tex/cv_pc.tex"

do_on_each_output_line 'find "$source_dir/tex" -type f -name "*.tex"' '
    current_target="$(dirname $target_dir/${line##$source_dir})"
    mkdir -p "$current_target"
    pdflatex -synctex=1 -interaction=nonstopmode -output-directory "$current_target" "$line"'
