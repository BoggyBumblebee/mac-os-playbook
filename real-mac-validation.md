# Fresh Mac Validation Checklist

Use this when testing the playbook on real Apple hardware after a clean macOS
install. Tart is useful for fast repeatable checks, but a real Mac is the only
reliable way to validate App Store installs, Apple ID dependent apps, and the
final Dock with all app sources available.

## Before Starting

Record the test context before making changes:

- Mac model:
- macOS version:
- Local admin username:
- Apple ID signed into App Store: yes / no
- Network: stable Wi-Fi or Ethernet
- Power: plugged in

Complete Apple's setup assistant, create the local admin account, and sign into
the App Store before running the playbook. The `mas` role cannot sign into the
App Store for you.

Keynote, Numbers, and Pages currently require macOS 15.6 or later from the App
Store. If the clean Mac is on an older macOS release, expect those MAS installs
to fail until macOS is updated.

## Bootstrap

Install the command line tools if they are not already present:

```bash
xcode-select --install
```

Install Homebrew, then make it available in the current shell:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
eval "$(/opt/homebrew/bin/brew shellenv)"
```

Install the tools needed to run the playbook:

```bash
brew install ansible git
```

Clone this fork and install the Ansible roles:

```bash
git clone https://github.com/BoggyBumblebee/mac-os-playbook.git
cd mac-os-playbook
ansible-galaxy install -r requirements.yml
```

## Dry Run

Run a syntax check first:

```bash
ansible-playbook main.yml --syntax-check
```

Then run check mode and keep the log:

```bash
ansible-playbook main.yml --ask-become-pass --check 2>&1 | tee ~/mac-os-playbook-check.log
```

Expected result: no failed tasks. Some tasks can report changes in check mode
because Homebrew, MAS, Dock, and macOS defaults are not perfectly dry-run
friendly.

## First Real Run

Run the full playbook:

```bash
ansible-playbook main.yml --ask-become-pass 2>&1 | tee ~/mac-os-playbook-first-run.log
```

If macOS prompts for permissions, approve the prompt and note which app or task
triggered it. If a task fails, capture the task name and the last 30 lines of
output before applying any manual fix.

## Second Run

Run the playbook again to check repeatability:

```bash
ansible-playbook main.yml --ask-become-pass 2>&1 | tee ~/mac-os-playbook-second-run.log
```

Expected result: no failed tasks. A small number of changed tasks can be
acceptable for `latest` packages, Homebrew metadata, MAS state, or Dock restarts,
but any repeated functional change should be investigated.

## Verification Commands

Capture installed package state:

```bash
brew list --formula | sort > ~/mac-os-playbook-brew-formulae.txt
brew list --cask | sort > ~/mac-os-playbook-brew-casks.txt
mas list > ~/mac-os-playbook-mas.txt
```

Check the shell dependencies that previously failed in the VM:

```bash
test -r /opt/homebrew/share/zsh-history-substring-search/zsh-history-substring-search.zsh
command -v thefuck
```

Check that launching a shell does not modify `.zshrc`:

```bash
cp ~/.zshrc /tmp/zshrc.before
zsh -lic exit
cmp -s /tmp/zshrc.before ~/.zshrc && echo ".zshrc stable" || echo ".zshrc changed during startup"
```

Check the dotfile links and macOS settings script:

```bash
test -L ~/.zshrc && readlink ~/.zshrc
test -L ~/.osx && readlink ~/.osx
test -x ~/.osx
```

Spot-check key app installs:

```bash
test -d "/Applications/Xcode.app" && echo "Xcode installed"
test -d "/Applications/Slack.app" && echo "Slack installed"
test -d "/Applications/reMarkable.app" && echo "reMarkable installed"
test -d "/Applications/Developer.app" && echo "Developer installed"
test -d "/Applications/iStatistica Pro.app" && echo "iStatistica Pro installed"
test -d "/Applications/Visual Studio Code.app" && echo "Visual Studio Code installed"
```

## Visual Checks

Log out and back in, or restart, before judging final UI state.

Confirm:

- Opening Terminal.app shows no startup errors.
- Homebrew-installed apps are present in `/Applications`.
- MAS-installed apps are present in `/Applications`.
- Xcode opens far enough to accept any required license or install additional components.
- The Dock order matches `dockitems_persist` in `config.yml`.
- Apps currently held in `dockitems_pending_install_source` are not expected in the managed Dock yet.
- Finder and System Settings preferences changed by `~/.osx` match the intended behavior.
- Microsoft Office, JetBrains Toolbox, Photos, Music, Dropbox, and any other account-bound apps can complete their first launch sign-in or sync flow.

## Failure Notes

For each failure, record:

- Command that was running.
- Failing Ansible task name.
- Error message.
- Whether the failure disappears on a second run.
- Whether the fix was manual, config-only, or playbook code.

Keep the logs in the home folder until the validation pass is complete.
