#!/usr/bin/env bash
set -euo pipefail

TARGET_DIR="."
REMOTE_MAIN=""
REMOTE_PUSH=""
ORG_URL=""
USER_URL=""

# --- Functions ---
configure_user() {
  local repo_url="$1"
  local repo_path="$2"

  # Extract host from repo URL
  local host
  host=$(echo "$repo_url" | sed -E 's|^[^@]+@||; s|^[a-z]+://([^/]+).*|\1|; s|:.*||')
  local host_first
  host_first=$(echo "$host" | cut -d. -f1 | tr '[:lower:]' '[:upper:]')

  local user_name_var="ALCHEMIST_${host_first}_USER_NAME"
  local user_mail_var="ALCHEMIST_${host_first}_USER_MAIL"

  if [[ -n "${!user_name_var:-}" ]]; then
    echo "Configuring user.name = ${!user_name_var}"
    git -C "$repo_path" config user.name "${!user_name_var}"
  fi

  if [[ -n "${!user_mail_var:-}" ]]; then
    echo "Configuring user.email = ${!user_mail_var}"
    git -C "$repo_path" config user.email "${!user_mail_var}"
  fi
}

clone_and_configure() {
  local repo="$1"
  local base_path="$2"

  local repo_name=${repo##*/}
  repo_name=${repo_name%.git}
  local repo_path="$base_path/$repo_name"

  if [[ ! -d "$repo_path" ]]; then
    echo "Cloning $repo ..."
    if ! git clone "$repo" "$repo_path"; then
      echo "SSH clone failed for $repo, trying HTTPS..."
      # Convert SSH → HTTPS for GitHub/GitLab
      https_url=$(echo "$repo" | sed -E 's|^[^@]+@([^:]+):|https://\1/|')
      if git clone "$https_url" "$repo_path"; then
        repo="$https_url"
      else
        echo "Failed to clone $repo (SSH and HTTPS)."
        return 1
      fi
    fi

    configure_user "$repo" "$repo_path"

    # Add push remote if template given
    if [[ -n "$REMOTE_PUSH" ]]; then
      push_url="${REMOTE_PUSH//\*/$repo_name}"
      echo "Adding push remote: $push_url"
      git -C "$repo_path" remote set-url --add --push origin "$push_url"
    fi
  else
    echo "Skipping $repo_name (already exists)"
  fi
}

# --- Parse args ---
while [[ $# -gt 0 ]]; do
  case "$1" in
    --all)
      if [[ -n "${2:-}" && ! "$2" =~ ^-- ]]; then
        REMOTE_MAIN="$2"
        shift 2
      else
        echo "Error: --all requires a remote URL"
        exit 1
      fi
      ;;
    --push)
      if [[ -n "${2:-}" && ! "$2" =~ ^-- ]]; then
        REMOTE_PUSH="$2"
        shift 2
      else
        echo "Error: --push requires a remote URL"
        exit 1
      fi
      ;;
    --org)
      if [[ -n "${2:-}" && ! "$2" =~ ^-- ]]; then
        ORG_URL="$2"
        shift 2
      else
        echo "Error: --org requires a GitHub org URL"
        exit 1
      fi
      ;;
    --user)
      if [[ -n "${2:-}" && ! "$2" =~ ^-- ]]; then
        USER_URL="$2"
        shift 2
      else
        echo "Error: --user requires a GitHub user URL"
        exit 1
      fi
      ;;
    *)
      if [[ "$1" == /* || "$1" == ./* || "$1" == "~"* ]]; then
        TARGET_DIR="$1"
      else
        echo "Unknown argument: $1"
        exit 1
      fi
      shift
      ;;
  esac
done

# --- ORG or USER MODE ---
if [[ -n "$ORG_URL" || -n "$USER_URL" ]]; then
  if [[ -n "$ORG_URL" ]]; then
    entity_name=$(basename "$ORG_URL")

    if [[ "$ORG_URL" == *"gitlab.com"* ]]; then
      group_enc=$(echo -n "$entity_name" | jq -s -R -r @uri)
      api_url="https://gitlab.com/api/v4/groups/$group_enc/projects?per_page=200"
      repo_field="ssh_url_to_repo"
    else
      api_url="https://api.github.com/orgs/$entity_name/repos?per_page=200"
      repo_field="ssh_url"
    fi

  else
    entity_name=$(basename "$USER_URL")

    if [[ "$USER_URL" == *"gitlab.com"* ]]; then
      user_id=$(curl -s "https://gitlab.com/api/v4/users?username=$entity_name" | jq -r '.[0].id')
      if [[ -z "$user_id" || "$user_id" == "null" ]]; then
        echo "Error: Could not resolve GitLab user $entity_name"
        exit 1
      fi
      api_url="https://gitlab.com/api/v4/users/$user_id/projects?per_page=200"
      repo_field="ssh_url_to_repo"
    else
      api_url="https://api.github.com/users/$entity_name/repos?per_page=200"
      repo_field="ssh_url"
    fi
  fi

  mapfile -t repos < <(curl -s "$api_url" | jq -r ".[].$repo_field")

  if [[ ${#repos[@]} -eq 0 ]]; then
    echo "No repositories found (maybe API rate limit?)."
    exit 1
  fi

  echo "Found ${#repos[@]} repositories."
  echo
  read -rp "Clone all repositories into $TARGET_DIR/$entity_name ? [y/N] " all_answer

  base_path="$TARGET_DIR/$entity_name"
  mkdir -p "$base_path"

  if [[ "$all_answer" =~ ^[Yy]$ ]]; then
    for repo in "${repos[@]}"; do
      clone_and_configure "$repo" "$base_path"
    done
  fi

  # --- endless loop selection ---
  selected=()
  while true; do
    clear
    echo "Repositories in $entity_name"
    echo "=========================="
    i=0
    for repo in "${repos[@]}"; do
      repo_name=${repo##*/}
      repo_name=${repo_name%.git}
      printf " [%2d] %s\n" "$i" "$repo_name"
      ((i+=1))
    done
    echo
    if [[ ${#selected[@]} -gt 0 ]]; then
      echo "Selected so far:"
      printf '  - %s\n' "${selected[@]}"
      echo
    fi

    read -rp "Select repo #, 'c' to clone selected, or 'q' to quit: " choice
    if [[ "$choice" == "q" ]]; then
      echo "Bye!"
      break
    elif [[ "$choice" == "c" ]]; then
      for repo in "${selected[@]}"; do
        clone_and_configure "$repo" "$base_path"
      done
      selected=()  # reset after cloning
      read -rp "Press Enter to continue..."
    elif [[ "$choice" =~ ^[0-9]+$ ]] && (( choice < ${#repos[@]} )); then
      candidate="${repos[$choice]}"
      already=false
      for sel in "${selected[@]}"; do
        if [[ "$sel" == "$candidate" ]]; then
          already=true
          break
        fi
      done
      if $already; then
        echo "Repo already selected: $candidate"
        sleep 1
      else
        selected+=("$candidate")
      fi
    else
      echo "Invalid choice"
      sleep 1
    fi
  done

  exit 0
fi

# --- Normal single-repo clone mode ---
if [[ -z "$REMOTE_MAIN" ]]; then
  echo "Usage:"
  echo "  gitclone <target-dir> --all <remote> [--push <remote>]"
  echo "  gitclone <target-dir> --org <org-url>"
  echo "  gitclone <target-dir> --user <user-url>"
  exit 1
fi

# Derive repo folder name
repo_name=$(basename -s .git "$REMOTE_MAIN")

if [[ "$TARGET_DIR" != "." ]]; then
  if [[ -d "$TARGET_DIR" ]]; then
    TARGET_DIR="$TARGET_DIR/$repo_name"
  fi
fi

echo "Cloning $REMOTE_MAIN into $TARGET_DIR..."
git clone "$REMOTE_MAIN" "$TARGET_DIR"

if [[ -n "$REMOTE_PUSH" ]]; then
  push_url="${REMOTE_PUSH//\*/$repo_name}"
  echo "Adding push remote: $push_url"
  git -C "$TARGET_DIR" remote set-url --add --push origin "$push_url"
fi

configure_user "$REMOTE_MAIN" "$TARGET_DIR"

echo "Done."
