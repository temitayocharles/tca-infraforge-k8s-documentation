#!/bin/bash

# Script to convert all .md files to .html using template.html

for file in *.md; do
  if [[ "$file" == "template.html" ]]; then continue; fi
  echo "Converting $file to ${file%.md}.html"
  # Convert markdown to HTML
  html_body=$(pandoc "$file" -t html --wrap=none)
  # Use python to replace $body$ in template
  python3 -c "
import sys
html_body = r'''$html_body'''
with open('template.html', 'r') as f:
    template = f.read()
with open('${file%.md}.html', 'w') as f:
    f.write(template.replace('\$body\$', html_body))
"
done

echo "Conversion complete."
