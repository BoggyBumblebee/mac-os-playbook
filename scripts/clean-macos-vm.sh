#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

DEFAULT_TART_IMAGE="ghcr.io/cirruslabs/macos-sequoia-base:latest"
DEFAULT_TART_VM="mac-os-playbook-test"
DEFAULT_TART_USER="admin"
DEFAULT_TART_PASS="admin"
DEFAULT_TART_CPU="4"
DEFAULT_TART_MEMORY="8192"
DEFAULT_TART_DISK_SIZE="80"
DEFAULT_SKIP_TAGS="mas,post"
DEFAULT_GUEST_WORKDIR="mac-os-playbook-validation"

usage() {
  cat <<'USAGE'
Usage:
  scripts/clean-macos-vm.sh host-check
  scripts/clean-macos-vm.sh native-notes
  scripts/clean-macos-vm.sh guest [--real] [--idempotence] [--skip-tags TAGS] [--no-become-pass]
  scripts/clean-macos-vm.sh tart [options]

Commands:
  host-check       Check whether this Mac can host Apple Virtualization.framework VMs.
  native-notes     Print the manual native VM workflow for VirtualBuddy, UTM, or Apple's sample.
  guest            Run playbook validation inside a macOS VM from the checked-out repo.
  tart             Create/start a Tart VM, copy this repo in, and run guest validation over SSH.

Tart options:
  --vm NAME             VM name. Default: mac-os-playbook-test
  --image IMAGE         Tart image to clone. Default: ghcr.io/cirruslabs/macos-sequoia-base:latest
  --user USER           Guest SSH user. Default: admin
  --password PASSWORD   Guest SSH password. Default: admin
  --cpu COUNT           vCPU count for a new VM. Default: 4
  --memory MIB          Memory for a new VM. Default: 8192
  --disk-size GB        Disk size for a new VM. Default: 80
  --real                Run a real playbook pass after syntax/check-mode validation.
  --idempotence         After --real, run a second real pass and expect changed=0.
  --skip-tags TAGS      Tags to skip. Default: mas,post
  --no-become-pass      Do not ask for a sudo/become password. Useful for CI-style VM images.
  --keep-running        Leave the Tart VM running after validation.

Environment overrides:
  TART_VM, TART_IMAGE, TART_USER, TART_PASS, TART_CPU, TART_MEMORY,
  TART_DISK_SIZE, PLAYBOOK_SKIP_TAGS

Notes:
  - Tart uses Apple's Virtualization.framework under the hood.
  - Guest validation bootstraps Homebrew and Ansible when they are missing.
  - Dotfiles are pre-seeded before check mode so the dotfiles role can be tested
    in clean macOS VMs.
  - Mac App Store automation is skipped by default because Apple Media Services
    are not available in macOS VMs.
  - The guest command also works in native-framework VMs created with
    VirtualBuddy, UTM, or Apple's sample app.
USAGE
}

die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

log() {
  printf '==> %s\n' "$*"
}

have_command() {
  command -v "$1" >/dev/null 2>&1
}

load_homebrew_environment() {
  local prefix

  if have_command brew; then
    return 0
  fi

  for prefix in /opt/homebrew /usr/local; do
    if [[ -x "${prefix}/bin/brew" ]]; then
      eval "$("${prefix}/bin/brew" shellenv)"
      return 0
    fi
  done

  return 1
}

install_homebrew() {
  log "Installing Homebrew in the guest."
  NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  load_homebrew_environment || true
  have_command brew || die "Homebrew installation completed, but brew is still not on PATH."
}

macos_major_version() {
  sw_vers -productVersion | awk -F. '{print $1}'
}

host_check() {
  [[ "$(uname -s)" == "Darwin" ]] || die "macOS host required."

  local arch
  arch="$(uname -m)"
  [[ "${arch}" == "arm64" ]] || die "macOS guest virtualization requires Apple Silicon for this workflow."

  local major
  major="$(macos_major_version)"
  if [[ "${major}" -lt 13 ]]; then
    die "macOS 13 or newer is recommended for Tart directory sharing."
  fi

  log "Host supports the intended Apple Virtualization.framework workflow."
  log "Architecture: ${arch}; macOS: $(sw_vers -productVersion)"

  if [[ "${major}" -lt 15 ]]; then
    log "Apple Account/iCloud support in macOS guests needs macOS 15+ on host and guest."
  fi

  log "Mac App Store / Apple Media Services remain unsuitable for VM validation; skip mas by default."
}

native_notes() {
  cat <<'NOTES'
Native Apple Virtualization.framework workflow:

1. Create a macOS VM using one of:
   - VirtualBuddy
   - UTM with the Apple Virtualization backend
   - Apple's Virtualization.framework sample app

2. In the guest, create an admin user and enable Remote Login if you want SSH.

3. Copy or clone this repository into the guest.

4. From the repository root inside the guest, run:

   scripts/clean-macos-vm.sh guest

5. For a real provision after check-mode passes, run:

   scripts/clean-macos-vm.sh guest --real --idempotence

The guest workflow skips mas and post tasks by default. Dotfiles are pre-seeded
before check mode so the dotfiles role and .osx handoff can still be tested in a
clean VM.
NOTES
}

ensure_guest_tools() {
  load_homebrew_environment || true

  if ! have_command brew; then
    install_homebrew
  fi

  if ! have_command ansible-playbook; then
    log "Installing Ansible in the guest with Homebrew."
    brew install ansible
    load_homebrew_environment || true
  fi

  if ! have_command git; then
    log "Installing Git in the guest with Homebrew."
    brew install git
    load_homebrew_environment || true
  fi
}

run_ansible_playbook() {
  local ask_become_pass="$1"
  shift

  if [[ "${ask_become_pass}" == true ]]; then
    ansible-playbook "$@" --ask-become-pass
  else
    ansible-playbook "$@"
  fi
}

config_value() {
  local key="$1"
  local config_file="default.config.yml"

  if [[ -f config.yml ]]; then
    config_file="config.yml"
  fi

  awk -v key="${key}" '
    $0 ~ "^" key ":" {
      value = $0
      sub("^[^:]+:[[:space:]]*", "", value)
      print value
      exit
    }
  ' "${config_file}" \
    | sed 's/^"//; s/"$//; s/^'\''//; s/'\''$//'
}

config_list_values() {
  local key="$1"
  local config_file="default.config.yml"

  if [[ -f config.yml ]]; then
    config_file="config.yml"
  fi

  awk -v key="${key}" '
    $0 ~ "^" key ":" { in_list = 1; next }
    in_list && /^[^[:space:]-]/ { exit }
    in_list && /^[[:space:]]*-/ {
      value = $0
      sub(/^[[:space:]]*-[[:space:]]*/, "", value)
      gsub(/^"|"$/, "", value)
      gsub(/^'\''|'\''$/, "", value)
      print value
    }
  ' "${config_file}"
}

expand_guest_path() {
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

prepare_dotfiles_for_check_mode() {
  local configure_dotfiles
  configure_dotfiles="$(config_value configure_dotfiles)"
  [[ "${configure_dotfiles}" == true ]] || return 0

  local repo destination version
  repo="$(config_value dotfiles_repo)"
  destination="$(expand_guest_path "$(config_value dotfiles_repo_local_destination)")"
  version="$(config_value dotfiles_repo_version)"

  [[ -n "${repo}" ]] || return 0
  [[ -n "${destination}" ]] || return 0
  [[ -n "${version}" ]] || version="master"

  log "Pre-seeding dotfiles for check-mode validation."
  mkdir -p "$(dirname "${destination}")"
  if [[ -d "${destination}/.git" ]]; then
    git -C "${destination}" fetch --depth 1 origin "${version}"
    git -C "${destination}" checkout -f FETCH_HEAD
  else
    rm -rf "${destination}"
    git clone --depth 1 --branch "${version}" "${repo}" "${destination}"
  fi

  while IFS= read -r dotfile; do
    [[ -n "${dotfile}" ]] || continue
    [[ -e "${destination}/${dotfile}" ]] \
      || die "Configured dotfile does not exist in ${repo}: ${dotfile}"
  done < <(config_list_values dotfiles_files)
}

run_guest_validation() {
  local real_run=false
  local idempotence=false
  local skip_tags="${PLAYBOOK_SKIP_TAGS:-${DEFAULT_SKIP_TAGS}}"
  local ask_become_pass=true

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --real)
        real_run=true
        shift
        ;;
      --idempotence)
        idempotence=true
        shift
        ;;
      --skip-tags)
        skip_tags="${2:?missing value for --skip-tags}"
        shift 2
        ;;
      --no-become-pass)
        ask_become_pass=false
        shift
        ;;
      --help|-h)
        usage
        exit 0
        ;;
      *)
        die "Unknown guest option: $1"
        ;;
    esac
  done

  [[ -f "${REPO_ROOT}/main.yml" ]] || die "Run guest validation from this repository checkout."

  ensure_guest_tools

  log "Installing Ansible Galaxy dependencies."
  ansible-galaxy install -r requirements.yml

  prepare_dotfiles_for_check_mode

  log "Running syntax check."
  ansible-playbook main.yml --syntax-check

  log "Running check-mode validation with --skip-tags ${skip_tags}."
  run_ansible_playbook "${ask_become_pass}" main.yml --check --diff --skip-tags "${skip_tags}"

  if [[ "${real_run}" == true ]]; then
    log "Running real playbook pass with --skip-tags ${skip_tags}."
    run_ansible_playbook "${ask_become_pass}" main.yml --skip-tags "${skip_tags}"
  else
    log "Skipping real provision pass. Add --real after check-mode looks good."
  fi

  if [[ "${idempotence}" == true ]]; then
    [[ "${real_run}" == true ]] || die "--idempotence requires --real."

    local idempotence_log
    idempotence_log="$(mktemp)"
    log "Running idempotence pass; expecting changed=0 and failed=0."
    run_ansible_playbook "${ask_become_pass}" main.yml --skip-tags "${skip_tags}" | tee "${idempotence_log}"
    tail "${idempotence_log}" | grep -q 'changed=0.*failed=0' \
      || die "Idempotence check failed. Inspect ${idempotence_log} in the guest."
    log "Idempotence check passed."
  fi
}

tart_vm_exists() {
  tart list --source local --quiet 2>/dev/null | grep -Fxq "$1"
}

wait_for_tart_ip() {
  local vm="$1"
  local attempts=90
  local ip=""

  for _ in $(seq 1 "${attempts}"); do
    ip="$(tart ip "${vm}" 2>/dev/null || true)"
    if [[ -n "${ip}" ]]; then
      printf '%s\n' "${ip}"
      return 0
    fi
    sleep 2
  done

  die "Timed out waiting for an IP address from Tart VM ${vm}."
}

tart_ssh_options() {
  printf '%s\n' \
    -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    -o PreferredAuthentications=password \
    -o PubkeyAuthentication=no \
    -o IdentitiesOnly=yes
}

wait_for_ssh() {
  local user="$1"
  local password="$2"
  local ip="$3"
  local attempts=90
  local ssh_options=()

  have_command sshpass || die "Install sshpass first: brew install cirruslabs/cli/sshpass"
  while IFS= read -r option; do
    ssh_options+=("${option}")
  done < <(tart_ssh_options)

  for _ in $(seq 1 "${attempts}"); do
    if sshpass -p "${password}" ssh \
      "${ssh_options[@]}" \
      -o ConnectTimeout=5 \
      "${user}@${ip}" "printf ready" >/dev/null 2>&1; then
      return 0
    fi
    sleep 2
  done

  die "Timed out waiting for SSH on ${user}@${ip}."
}

tart_ssh() {
  local user="$1"
  local password="$2"
  local ip="$3"
  local ssh_options=()
  shift 3
  while IFS= read -r option; do
    ssh_options+=("${option}")
  done < <(tart_ssh_options)

  sshpass -p "${password}" ssh \
    "${ssh_options[@]}" \
    "${user}@${ip}" "$@"
}

tart_copy_repo_to_guest() {
  local user="$1"
  local password="$2"
  local ip="$3"
  local guest_workdir="$4"
  local archive

  archive="$(mktemp -t mac-os-playbook.XXXXXX.tar.gz)"
  tar \
    --exclude .git \
    --exclude .ansible \
    --exclude roles \
    --exclude .DS_Store \
    -czf "${archive}" \
    -C "${REPO_ROOT}" \
    .

  tart_ssh "${user}" "${password}" "${ip}" "rm -rf '${guest_workdir}' && mkdir -p '${guest_workdir}'"
  local ssh_options=()
  while IFS= read -r option; do
    ssh_options+=("${option}")
  done < <(tart_ssh_options)
  sshpass -p "${password}" scp \
    "${ssh_options[@]}" \
    "${archive}" "${user}@${ip}:/tmp/mac-os-playbook.tar.gz"
  tart_ssh "${user}" "${password}" "${ip}" "tar -xzf /tmp/mac-os-playbook.tar.gz -C '${guest_workdir}'"
  rm -f "${archive}"
}

run_tart_validation() {
  local vm="${TART_VM:-${DEFAULT_TART_VM}}"
  local image="${TART_IMAGE:-${DEFAULT_TART_IMAGE}}"
  local user="${TART_USER:-${DEFAULT_TART_USER}}"
  local password="${TART_PASS:-${DEFAULT_TART_PASS}}"
  local cpu="${TART_CPU:-${DEFAULT_TART_CPU}}"
  local memory="${TART_MEMORY:-${DEFAULT_TART_MEMORY}}"
  local disk_size="${TART_DISK_SIZE:-${DEFAULT_TART_DISK_SIZE}}"
  local skip_tags="${PLAYBOOK_SKIP_TAGS:-${DEFAULT_SKIP_TAGS}}"
  local real_run=false
  local idempotence=false
  local keep_running=false

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --vm)
        vm="${2:?missing value for --vm}"
        shift 2
        ;;
      --image)
        image="${2:?missing value for --image}"
        shift 2
        ;;
      --user)
        user="${2:?missing value for --user}"
        shift 2
        ;;
      --password)
        password="${2:?missing value for --password}"
        shift 2
        ;;
      --cpu)
        cpu="${2:?missing value for --cpu}"
        shift 2
        ;;
      --memory)
        memory="${2:?missing value for --memory}"
        shift 2
        ;;
      --disk-size)
        disk_size="${2:?missing value for --disk-size}"
        shift 2
        ;;
      --real)
        real_run=true
        shift
        ;;
      --idempotence)
        idempotence=true
        shift
        ;;
      --skip-tags)
        skip_tags="${2:?missing value for --skip-tags}"
        shift 2
        ;;
      --keep-running)
        keep_running=true
        shift
        ;;
      --help|-h)
        usage
        exit 0
        ;;
      *)
        die "Unknown tart option: $1"
        ;;
    esac
  done

  host_check
  have_command tart || die "Install Tart first: brew install openai/tools/tart"
  have_command sshpass || die "Install sshpass first: brew install cirruslabs/cli/sshpass"

  if ! tart_vm_exists "${vm}"; then
    log "Cloning Tart VM ${vm} from ${image}."
    tart clone "${image}" "${vm}"
    tart set "${vm}" --cpu "${cpu}" --memory "${memory}" --disk-size "${disk_size}"
  else
    log "Using existing Tart VM ${vm}."
  fi

  log "Starting Tart VM ${vm} in the background."
  tart run --no-graphics "${vm}" >/tmp/"${vm}".log 2>&1 &
  local tart_pid=$!
  TART_CLEANUP_VM="${vm}"
  TART_CLEANUP_PID="${tart_pid}"
  TART_CLEANUP_KEEP_RUNNING="${keep_running}"

  cleanup() {
    if [[ "${TART_CLEANUP_KEEP_RUNNING:-false}" != true ]]; then
      log "Stopping Tart VM ${TART_CLEANUP_VM}."
      tart stop "${TART_CLEANUP_VM}" >/dev/null 2>&1 || true
    else
      log "Leaving Tart VM ${TART_CLEANUP_VM} running."
    fi
    wait "${TART_CLEANUP_PID}" >/dev/null 2>&1 || true
  }
  trap cleanup EXIT

  local ip
  ip="$(wait_for_tart_ip "${vm}")"
  log "Tart VM IP: ${ip}"
  wait_for_ssh "${user}" "${password}" "${ip}"

  log "Copying repository snapshot into the guest."
  tart_copy_repo_to_guest "${user}" "${password}" "${ip}" "${DEFAULT_GUEST_WORKDIR}"

  local guest_args=(guest --no-become-pass --skip-tags "${skip_tags}")
  [[ "${real_run}" == true ]] && guest_args+=(--real)
  [[ "${idempotence}" == true ]] && guest_args+=(--idempotence)

  log "Running guest validation."
  tart_ssh "${user}" "${password}" "${ip}" \
    "cd '${DEFAULT_GUEST_WORKDIR}' && bash scripts/clean-macos-vm.sh ${guest_args[*]}"
}

main() {
  local command="${1:-}"
  [[ -n "${command}" ]] || {
    usage
    exit 1
  }
  shift || true

  case "${command}" in
    host-check)
      host_check "$@"
      ;;
    native-notes)
      native_notes "$@"
      ;;
    guest)
      run_guest_validation "$@"
      ;;
    tart)
      run_tart_validation "$@"
      ;;
    --help|-h|help)
      usage
      ;;
    *)
      die "Unknown command: ${command}"
      ;;
  esac
}

main "$@"
