#!/bin/bash -eu

this_dir="$(dirname "$0")"
. "$this_dir/functions.sh"

root_dir="$this_dir/../../"
resource_dir="$root_dir/src/resources"
source_dir="$root_dir/bin/generated"
target_dir="$root_dir/bin"

do_on_each_output_line 'find "$source_dir/tex" -type f -name "*.tex"' '
    current_target="$(dirname $target_dir/${line##$source_dir})"
    mkdir -p "$current_target"
    TEXINPUTS="$resource_dir:${TEXINPUTS-}" pdflatex -synctex=1 -interaction=nonstopmode -output-directory "$current_target" "$line"'
