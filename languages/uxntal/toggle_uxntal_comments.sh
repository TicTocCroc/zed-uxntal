#!/bin/bash

file_path="$ZED_FILE"
selection="$ZED_SELECTED_TEXT"
row_number="$ZED_ROW"

# Check if file exists
if [ ! -f "$file_path" ]; then
    echo "Error: File '$file_path' does not exist"
    exit 1
fi

# Validate row number is a positive integer
if ! echo "$row_number" | grep -qE '^[1-9][0-9]*$'; then
    echo "Error: Row number must be a positive integer"
    exit 1
fi

# Get total lines in file
total_lines=$(wc -l < "$file_path")

# Check if row number is within file bounds
if [ "$row_number" -gt "$total_lines" ]; then
    echo "Error: Row number $row_number exceeds file length ($total_lines lines)"
    exit 1
fi

# Determine the range of rows to act on
start_row="$row_number"
if [ -z "$selection" ]; then
    # Empty selection: act on the single row
    end_row="$start_row"
else
    # Non-empty selection: calculate end row based on selection content
    # Count newlines in selection to determine how many lines it spans
    newline_count=$(printf '%s' "$selection" | grep -c $'\n' || echo 0)
    if (( $newline_count > 0)); then
      newline_count=$((newline_count - 1))
    fi;
    end_row=$((start_row + newline_count))

    # Ensure end_row doesn't exceed file bounds
    if [ "$end_row" -gt "$total_lines" ]; then
        end_row="$total_lines"
    fi
fi

# Get the first and last lines of the range
first_line=$(awk "NR==$start_row" "$file_path")
last_line=$(awk "NR==$end_row" "$file_path")

# Trim whitespace to check for parentheses
first_trimmed=$(echo "$first_line" | awk '{gsub(/^[ \t]+/, ""); print}')
last_trimmed=$(echo "$last_line" | awk '{gsub(/[ \t]+$/, ""); print}')

# Check if first line starts with "( " and last line ends with " )"
starts_with_paren=false
ends_with_paren=false

case "$first_trimmed" in
    "( "*) starts_with_paren=true ;;
esac

case "$last_trimmed" in
    *" )") ends_with_paren=true ;;
esac

# Create a temporary file
temp_file="${file_path}.tmp.$$"

if [ "$starts_with_paren" = true ] && [ "$ends_with_paren" = true ]; then
    # Remove parentheses
    awk -v start="$start_row" -v end="$end_row" '
    {
        if (NR == start && NR == end) {
            # Remove "( " from beginning, preserving leading whitespace
            match($0, /^([ \t]*)/)
            leading = substr($0, 1, RLENGTH)
            rest = substr($0, RLENGTH + 1)
            if (substr(rest, 1, 2) == "( ") {
                rest = substr(rest, 3)
            }

            # Remove " )" from end, preserving trailing whitespace
            # First, find any trailing whitespace
            trailing_match = match(rest, /[ \t]*$/)
            if (trailing_match > 0) {
              trailing = substr(rest, trailing_match)
              content = substr(rest, 1, trailing_match - 1)

              if (match(content, /^(.*)( \))$/)) {
                  pre_comment_content = substr(content, 1, RLENGTH - 2)
                  print leading pre_comment_content trailing
              } else {
                  print leading content trailing
              }
            } else {
              if (match(content, /^(.*)( \))$/)) {
                  pre_comment_content = substr(content, 1, RLENGTH - 2)
                  print leading pre_comment_content
              } else {
                  print leading content
              }
            }
        } else if (NR == start) {
            # Remove "( " from beginning, preserving leading whitespace
            match($0, /^([ \t]*)/)
            leading = substr($0, 1, RLENGTH)
            rest = substr($0, RLENGTH + 1)
            if (substr(rest, 1, 2) == "( ") {
                rest = substr(rest, 3)
            }
            print leading rest
        } else if (NR == end) {
            # Remove " )" from end, preserving trailing whitespace
            # First, find any trailing whitespace
            trailing_match = match($0, /[ \t]*$/)
            if (trailing_match > 0) {
              trailing = substr($0, trailing_match)
              content = substr($0, 1, trailing_match - 1)

              if (match(content, /^(.*)( \))$/)) {
                  pre_comment_content = substr(content, 1, RLENGTH - 2)
                  print pre_comment_content trailing
              } else {
                  print content trailing
              }
            } else {
              if (match(content, /^(.*)( \))$/)) {
                  pre_comment_content = substr(content, 1, RLENGTH - 2)
                  print pre_comment_content
              } else {
                  print content
              }
            }
        } else {
            print $0
        }
    }' "$file_path" > "$temp_file"

    echo "Removed parentheses from lines $start_row to $end_row"
else
    # Add parentheses
    awk -v start="$start_row" -v end="$end_row" '
    {
        if (NR == start && NR == end) {
            # Add "( " after leading whitespace
            match($0, /^([ \t]*)/)
            leading = substr($0, 1, RLENGTH)
            rest = substr($0, RLENGTH + 1)

            # Add " )" before trailing whitespace
            # First, find any trailing whitespace
            trailing_match = match(rest, /[ \t]*$/)
            if (trailing_match > 0) {
                trailing = substr(rest, trailing_match)
                content = substr(rest, 1, trailing_match - 1)
                print leading "( " content " )" trailing
            } else {
                # No trailing whitespace
                print leading "( " rest " )"
            }
        } else if (NR == start) {
            # Add "( " after leading whitespace
            match($0, /^([ \t]*)/)
            leading = substr($0, 1, RLENGTH)
            rest = substr($0, RLENGTH + 1)
            print leading "( " rest
        } else if (NR == end) {
            # Add " )" before trailing whitespace
            # First, find any trailing whitespace
            trailing_match = match($0, /[ \t]*$/)
            if (trailing_match > 0) {
                trailing = substr($0, trailing_match)
                content = substr($0, 1, trailing_match - 1)
                print content " )" trailing
            } else {
                # No trailing whitespace
                print $0 " )"
            }
        } else {
            print $0
        }
    }' "$file_path" > "$temp_file"

    echo "Added parentheses to lines $start_row to $end_row"
fi

# Replace original file with modified version
mv "$temp_file" "$file_path"
