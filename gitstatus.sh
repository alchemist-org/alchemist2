#!/usr/bin/env bash

SHOW_URLS=false
SHOW_USERS=false
LOG_RANGE=""
FILTER=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --urls)  SHOW_URLS=true; shift ;;
    --users) SHOW_USERS=true; shift ;;
    --logs)
      if [[ -n "$2" && ! "$2" =~ ^-- ]]; then
        LOG_RANGE="$2"
        shift 2
      else
        LOG_RANGE="1 day ago"
        shift
      fi
      ;;
    *) FILTER="$1"; shift ;;  # catch-all = project filter
  esac
done

# Collect all repos
mapfile -t repos < <(find ~ -type d -name ".git" -exec dirname {} \; 2>/dev/null \
                     | grep -E "/[^/]*projects[^/]*/" \
                     | sort)

# Apply filter if set
if [[ -n "$FILTER" ]]; then
  mapfile -t repos < <(printf "%s\n" "${repos[@]}" | grep -i "$FILTER")

  if [[ ${#repos[@]} -eq 1 ]]; then
    repo="${repos[0]}"
    cd "$repo" || exit 1

    activate_cmd="exec bash"

    nohup io.elementary.terminal \
      --working-directory "$repo" \
      --commandline ""
      >/dev/null 2>&1 &

    disown
    exit 0
  else
    # 0 or >1 → just quit
    exit 0
  fi
fi


# === Normal interactive mode (no filter) ===
while true; do
  clear
  echo "Alchemist 2: git status"
  echo "======================="

  # Show global Git user config only if --users
  if $SHOW_USERS; then
    global_name=$(git config --global user.name 2>/dev/null || echo "N/A")
    global_email=$(git config --global user.email 2>/dev/null || echo "N/A")

    echo
    echo "User:  $global_name"
    echo "Email: $global_email"
    echo
  fi

  # Collect all repos once
  mapfile -t repos < <(find ~ -type d -name ".git" -exec dirname {} \; 2>/dev/null \
                       | grep -E "/[^/]*projects[^/]*/" | sort)

  last_top=""
  i=0

  for repo in "${repos[@]}"; do
    # extract the top-level projects folder (~/something-projects)
    top=$(echo "$repo" | sed -E "s|^$HOME(/[^/]*projects).*|\1|")

    # Print heading if group changed
    if [[ "$top" != "$last_top" ]]; then
      echo
      echo "~$top ##############################################################################################"
      echo
      last_top=$top
    fi

    repo_name=$(basename "$repo")
    printf " [%2d] ├── %s\n" "$i" "$repo_name"

    # === Show remote info if --urls ===
    remote_lines=()
    if $SHOW_URLS; then
      fetch_url=$(git -C "$repo" remote get-url origin 2>/dev/null || echo "")
      push_urls=$(git -C "$repo" remote get-url --push --all origin 2>/dev/null | sort -u)

      if [[ -n "$fetch_url" ]]; then
        remote_lines+=("      All:  $fetch_url")
      fi
      if [[ -n "$push_urls" ]]; then
        while IFS= read -r url; do
          if [[ "$url" != "$fetch_url" ]]; then
            remote_lines+=("      Push: $url")
          fi
        done <<< "$push_urls"
      fi

      for line in "${remote_lines[@]}"; do
        echo "$line"
      done
    fi

    # === Show user info if --users ===
    if $SHOW_USERS; then
      user_name=$(git -C "$repo" config user.name 2>/dev/null || echo "N/A")
      user_email=$(git -C "$repo" config user.email 2>/dev/null || echo "N/A")
      echo
      echo "      User:  $user_name"
      echo "      Email: $user_email"
    fi

    # === Show git logs if --logs <range> ===
    if [[ -n "$LOG_RANGE" ]]; then
      git -C "$repo" log --since="$LOG_RANGE" \
        --pretty=format:"      %C(yellow)%h%Creset %Cgreen%ad%Creset %C(bold blue)%an%Creset %s" \
        --date=short 2>/dev/null
    fi

    # === Show git status if dirty ===
    if ! git -C "$repo" diff --quiet || \
       ! git -C "$repo" diff --cached --quiet || \
       [[ -n "$(git -C "$repo" ls-files --others --exclude-standard)" ]]; then
      if ($SHOW_URLS && [[ "${#remote_lines[@]}" -gt 0 ]] && ! $SHOW_USERS) || [[ -n "$LOG_RANGE" ]]; then
        echo
      fi
      git -C "$repo" -c color.status=always status | sed "s/^/      /"
    fi

    ((i++))
  done

  echo
  read -rp "Open repo # (or 'q' to quit): " choice

  if [[ "$choice" == "q" || "$choice" == "quit" ]]; then
    echo "Bye!"
    break
  elif [[ "$choice" =~ ^[0-9]+$ ]] && (( choice < ${#repos[@]} )); then
    nohup $ALCHEMIST_TERMINAL_CMD "${repos[$choice]}" >/dev/null 2>&1 &
    disown
  else
    echo "Invalid choice"
    sleep 1
  fi
done
