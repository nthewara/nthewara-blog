#!/bin/bash
for f in "Pasted image "*.png; do
  [[ -f "$f" ]] && mv "$f" "${f#Pasted image }"
done
