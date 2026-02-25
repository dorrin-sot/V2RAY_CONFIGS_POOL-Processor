#!/usr/bin/env bash

set -euo pipefail

########################################
# Defaults
########################################
SPLIT_COUNTRIES=false
INCLUDE_MANAGER=false
LIMIT_FILES=""
FOREIGN_DIR="foreign-repo"
OUTPUT_FILE="concatenated_v2ray.txt"
MANAGER_URL="https://manager.farsonline24.ir"

rm -rf "$FOREIGN_DIR" countries

########################################
# Argument parsing
########################################
while [[ $# -gt 0 ]]; do
  case "$1" in
    --countries)
      SPLIT_COUNTRIES=true
      shift
      ;;
    --manager)
      INCLUDE_MANAGER=true
      shift
      ;;
    -n)
      if [[ -n "${2:-}" && "$2" =~ ^[0-9]+$ ]]; then
        LIMIT_FILES="$2"
        shift 2
      else
        echo "Error: -n requires a numeric argument"
        exit 1
      fi
      ;;
    *)
      echo "Unknown argument: $1"
      exit 1
      ;;
  esac
done

########################################
# Validation
########################################
if [[ ! -d "$FOREIGN_DIR" ]]; then
  echo "Error: directory '$FOREIGN_DIR' not found."
  exit 1
fi

########################################
# Optional: Manager data
########################################
TMP_MANAGER=""
if $INCLUDE_MANAGER; then
  TMP_MANAGER=$(mktemp)
  if curl -fsS "$MANAGER_URL" -o "$TMP_MANAGER"; then
    echo "Manager data fetched successfully."
  else
    echo "Manager fetch failed. Skipping."
    rm -f "$TMP_MANAGER"
    TMP_MANAGER=""
  fi
fi

########################################
# Collect files
########################################
mapfile -t FILES < <(ls "$FOREIGN_DIR"/v2ray_configs_*.txt 2>/dev/null | sort -V)

if [[ ${#FILES[@]} -eq 0 ]]; then
  echo "No matching config files found."
  exit 1
fi

# Apply -n limit (latest N)
if [[ -n "$LIMIT_FILES" ]]; then
  FILES=("${FILES[@]: -$LIMIT_FILES}")
fi

########################################
# Concatenate + Clean + Deduplicate
########################################
{
  if [[ -n "$TMP_MANAGER" ]]; then
    cat "$TMP_MANAGER"
  fi

  for f in "${FILES[@]}"; do
    cat "$f"
  done
} \
| sed 's/#.*📡/#📡/' \
| sort \
| uniq \
> "$OUTPUT_FILE"

rm -f "$TMP_MANAGER"

echo "Created $OUTPUT_FILE"
wc -l "$OUTPUT_FILE"

########################################
# Optional: Split by country
########################################
if $SPLIT_COUNTRIES; then
  rm -rf countries
  mkdir -p countries

  grep -oP '®️\K[^©️]+' "$OUTPUT_FILE" | sort -u | while read -r country; do
    filename=$(echo "$country" | tr ' ' '_' | tr -d '()')
    grep "®️$country©️" "$OUTPUT_FILE" > "countries/${filename}.txt"
  done

  echo "Country files generated in ./countries"
fi

echo "Done."
