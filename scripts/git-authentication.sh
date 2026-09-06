#!/usr/bin/env bash

set -euo pipefail

key_path="${GITHUB_SSH_KEY_PATH:-${HOME}/.ssh/id_ed25519_github}"
key_comment="${GITHUB_SSH_KEY_COMMENT:-}"
git_host="${GITHUB_SSH_HOST:-github.com}"
copy_to_clipboard=true
test_connection=true
force_key=false

usage() {
  cat <<'USAGE'
Usage:
  scripts/git-authentication.sh --email EMAIL [options]

Options:
  --email EMAIL       SSH key comment, usually the email address associated with GitHub.
  --key-path PATH     SSH private key path. Default: ~/.ssh/id_ed25519_github
  --host HOST         SSH host alias to configure. Default: github.com
  --force             Replace an existing key at --key-path.
  --no-clipboard      Do not copy the public key to the clipboard.
  --no-test           Do not run the final ssh -T connectivity check.
  -h, --help          Show this help.

Environment overrides:
  GITHUB_SSH_KEY_COMMENT, GITHUB_SSH_KEY_PATH, GITHUB_SSH_HOST
USAGE
}

log() {
  printf '==> %s\n' "$1"
}

die() {
  printf 'Error: %s\n' "$1" >&2
  exit 1
}

expand_path() {
  local path="$1"
  case "${path}" in
    "~")
      printf '%s\n' "${HOME}"
      ;;
    "~/"*)
      printf '%s/%s\n' "${HOME}" "${path:2}"
      ;;
    *)
      printf '%s\n' "${path}"
      ;;
  esac
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --email)
      key_comment="${2:?missing value for --email}"
      shift 2
      ;;
    --key-path)
      key_path="${2:?missing value for --key-path}"
      shift 2
      ;;
    --host)
      git_host="${2:?missing value for --host}"
      shift 2
      ;;
    --force)
      force_key=true
      shift
      ;;
    --no-clipboard)
      copy_to_clipboard=false
      shift
      ;;
    --no-test)
      test_connection=false
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      die "Unknown option: $1"
      ;;
  esac
done

[[ -n "${key_comment}" ]] || die "Pass --email EMAIL or set GITHUB_SSH_KEY_COMMENT."

key_path="$(expand_path "${key_path}")"
public_key_path="${key_path}.pub"
ssh_config_path="${HOME}/.ssh/config"
block_begin="# BEGIN managed GitHub SSH key for ${git_host}"
block_end="# END managed GitHub SSH key for ${git_host}"

mkdir -p "${HOME}/.ssh"
chmod 700 "${HOME}/.ssh"

if [[ -e "${key_path}" && "${force_key}" != true ]]; then
  log "Using existing SSH key at ${key_path}."
else
  if [[ -e "${key_path}" ]]; then
    log "Replacing SSH key at ${key_path}."
    rm -f "${key_path}" "${public_key_path}"
  else
    log "Generating SSH key at ${key_path}."
  fi

  ssh-keygen -q -t ed25519 -N '' -f "${key_path}" -C "${key_comment}" <<<y >/dev/null
fi

if [[ ! -e "${public_key_path}" ]]; then
  log "Regenerating missing public key at ${public_key_path}."
  ssh-keygen -y -f "${key_path}" > "${public_key_path}"
fi

chmod 600 "${key_path}"
chmod 644 "${public_key_path}"

log "Ensuring ssh-agent is running."
eval "$(ssh-agent -s)" >/dev/null

log "Adding SSH key to the macOS keychain."
if ! ssh-add --apple-use-keychain "${key_path}" >/dev/null 2>&1; then
  ssh-add -K "${key_path}" >/dev/null
fi

touch "${ssh_config_path}"
chmod 600 "${ssh_config_path}"

tmp_config="$(mktemp)"
awk -v begin="${block_begin}" -v end="${block_end}" '
  $0 == begin { skipping = 1; next }
  $0 == end { skipping = 0; next }
  !skipping { print }
' "${ssh_config_path}" > "${tmp_config}"

cat >> "${tmp_config}" <<EOF
${block_begin}
Host ${git_host}
  AddKeysToAgent yes
  UseKeychain yes
  IdentityFile ${key_path}
${block_end}
EOF

mv "${tmp_config}" "${ssh_config_path}"

log "Public key:"
printf '\n'
cat "${public_key_path}"
printf '\n'

if [[ "${copy_to_clipboard}" == true ]] && command -v pbcopy >/dev/null 2>&1; then
  pbcopy < "${public_key_path}"
  log "Copied public key to clipboard."
fi

printf '\n'
read -r -p "Add the public key to GitHub, then press Enter to continue..." _

if [[ "${test_connection}" == true ]]; then
  log "Testing SSH connectivity to ${git_host}."
  ssh -T "git@${git_host}"
fi
