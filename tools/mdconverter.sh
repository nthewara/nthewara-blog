#!/bin/bash
echo "$file" | sed -E 's/!\[\[Pasted image ([0-9]+)\.png.*\]\]/![\1](\1.png)/'
