#!/usr/bin/env bash

# Usage:
#   gitconfig --name "Your Name" --mail "email@example.com"
#   gitconfig ~/path/to/repos --name "Your Name" --mail "email@example.com"

set -e

# --- Argument parsing ---
TARGET=""
NAME=""
MAIL=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --name)
      NAME="$2"
      shift 2
      ;;
    --mail|--email)
      MAIL="$2"
      shift 2
      ;;
    -*)
      echo "Unknown argument: $1"
      exit 1
      ;;
    *)
      # First non-flag argument is the target directory
      TARGET="$1"
      shift
      ;;
  esac
done

if [[ -z "$NAME" || -z "$MAIL" ]]; then
  echo "Usage:"
  echo "  $0 [path] --name \"Your Name\" --mail \"email@example.com\""
  exit 1
fi

# --- Global config ---
if [[ -z "$TARGET" ]]; then
  echo "Setting global git config..."
  git config --global user.name "$NAME"
  git config --global user.email "$MAIL"
  echo "Done (global: $NAME <$MAIL>)"
  exit 0
fi

# --- Local config for all repos in the target path ---
if [[ ! -d "$TARGET" ]]; then
  echo "Path '$TARGET' does not exist"
  exit 1
fi

echo "Searching repositories in $TARGET ..."
mapfile -t repos < <(find "$TARGET" -type d -name ".git" -exec dirname {} \; 2>/dev/null)

for repo in "${repos[@]}"; do
  echo "Setting config in $repo"
  git -C "$repo" config user.name "$NAME"
  git -C "$repo" config user.email "$MAIL"
done

echo "Done (repositories updated: ${#repos[@]})"
