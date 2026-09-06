#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: scripts/run-playbook.sh [options] [ansible-playbook options]

Runs main.yml with a friendlier hidden password prompt and useful log detail.

Options:
  --profile NAME          Set PLAYBOOK_MACHINE_PROFILE for this run.
  --check                 Run Ansible check mode and include --diff.
  --log PATH              Save full output to PATH while still showing it.
  --quiet                 Do not add Ansible -v automatically.
  --no-password-prompt    Do not prompt; also disables the playbook fallback prompt.
  -h, --help              Show this help.

All other arguments are passed through to ansible-playbook.
EOF
}

log_file=""
verbosity="-v"
prompt_for_password=true
syntax_check=false
declare -a ansible_args=()

export ANSIBLE_LOCAL_TEMP="${ANSIBLE_LOCAL_TEMP:-/tmp/ansible-local}"
export ANSIBLE_REMOTE_TEMP="${ANSIBLE_REMOTE_TEMP:-/tmp/ansible-remote}"
mkdir -p "${ANSIBLE_LOCAL_TEMP}" "${ANSIBLE_REMOTE_TEMP}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --profile)
      export PLAYBOOK_MACHINE_PROFILE="${2:?missing value for --profile}"
      shift 2
      ;;
    --check)
      ansible_args+=(--check --diff)
      shift
      ;;
    --log)
      log_file="${2:?missing value for --log}"
      shift 2
      ;;
    --quiet)
      verbosity=""
      shift
      ;;
    --no-password-prompt)
      prompt_for_password=false
      ansible_args+=(--extra-vars prompt_for_become_password=false)
      shift
      ;;
    --syntax-check)
      syntax_check=true
      ansible_args+=(--syntax-check)
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --)
      shift
      ansible_args+=("$@")
      break
      ;;
    *)
      ansible_args+=("$1")
      shift
      ;;
  esac
done

if [[ "${syntax_check}" == true ]]; then
  prompt_for_password=false
fi

if [[ "${prompt_for_password}" == true && -z "${PLAYBOOK_BECOME_PASSWORD:-}" ]]; then
  printf '%s\n' "This playbook needs your macOS account password for sudo and Homebrew cask installers."
  printf '%s\n' "Input is hidden: type the password, press Enter, and wait for Ansible to continue."
  read -r -s -p "macOS account password: " PLAYBOOK_BECOME_PASSWORD
  printf '\n'
  export PLAYBOOK_BECOME_PASSWORD
fi

if [[ -n "${PLAYBOOK_BECOME_PASSWORD:-}" ]]; then
  ansible_args+=(--extra-vars prompt_for_become_password=false)
fi

declare -a command=(ansible-playbook main.yml)
if [[ -n "${verbosity}" ]]; then
  command+=("${verbosity}")
fi
command+=("${ansible_args[@]}")

if [[ -n "${PLAYBOOK_MACHINE_PROFILE:-}" ]]; then
  printf '==> Machine profile: %s\n' "${PLAYBOOK_MACHINE_PROFILE}"
fi
printf '==> Running:'
printf ' %q' "${command[@]}"
printf '\n'

if [[ -n "${log_file}" ]]; then
  mkdir -p "$(dirname "${log_file}")"
  set +e
  "${command[@]}" 2>&1 | tee "${log_file}"
  status=${PIPESTATUS[0]}
  set -e
  exit "${status}"
fi

exec "${command[@]}"
