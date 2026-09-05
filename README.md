<img src="https://raw.githubusercontent.com/geerlingguy/mac-dev-playbook/master/files/Mac-Dev-Playbook-Logo.png" width="250" height="156" alt="Mac Dev Playbook Logo" />

# Mac Development Ansible Playbook

[![CI][badge-gh-actions]][link-gh-actions]

This playbook installs and configures most of the software I use on my Mac for web and software development. Some things in macOS are slightly difficult to automate, so I still have a few manual installation steps, but at least it's all documented here.

## Installation

  1. Ensure Apple's command line tools are installed (`xcode-select --install` to launch the installer).
  2. Install [Homebrew](https://brew.sh/), then add it to your current shell:

     ```bash
     /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
     eval "$(/opt/homebrew/bin/brew shellenv)"
     ```

  3. Install Ansible with Homebrew:

     ```bash
     brew install ansible
     ```

  4. Sign into the App Store if your configuration installs MAS apps.
  5. Clone or download this repository to your local drive.
  6. Run `ansible-galaxy install -r requirements.yml` inside this directory to install required Ansible roles.
  7. Run `ansible-playbook main.yml --ask-become-pass` inside this directory. Enter your macOS account password when prompted for the 'BECOME' password.

> Note: If some Homebrew commands fail, you might need to agree to Xcode's license or fix some other Brew issue. Run `brew doctor` to see if this is the case.

### Use with a remote Mac

You can use this playbook to manage other Macs as well; the playbook doesn't even need to be run from a Mac at all! If you want to manage a remote Mac, either another Mac on your network, or a hosted Mac like the ones from [MacStadium](https://www.macstadium.com), you just need to make sure you can connect to it with SSH:

  1. (On the Mac you want to connect to:) Go to System Settings > Sharing.
  2. Enable 'Remote Login'.

> You can also enable remote login on the command line:
>
>     sudo systemsetup -setremotelogin on

Then edit the `inventory` file in this repository and change the line that starts with `127.0.0.1` to:

```
[ip address or hostname of mac]  ansible_user=[mac ssh username]
```

If you need to supply an SSH password (if you don't use SSH keys), make sure to pass the `--ask-pass` parameter to the `ansible-playbook` command.

### GitHub SSH authentication helper

If you want to generate and register a GitHub SSH key manually, use the parameterized helper:

```bash
./git-authentication.sh --email you@example.com
```

The helper creates an ed25519 key, stores it in the macOS keychain, updates a managed `Host github.com` block in `~/.ssh/config`, copies the public key to the clipboard when `pbcopy` is available, and then tests `ssh -T git@github.com`.

### Running a specific set of tagged tasks

You can filter which part of the provisioning process to run by specifying a set of tags using `ansible-playbook`'s `--tags` flag. The tags available are `dotfiles`, `homebrew`, `mas`, `extra-packages` and `osx`.

    ansible-playbook main.yml -K --tags "dotfiles,homebrew"

## Overriding Defaults

Not everyone's development environment and preferred software configuration is the same.

You can override any of the defaults configured in `default.config.yml` by creating a `config.yml` file and setting the overrides in that file. For example, you can customize the installed packages and apps with something like:

```yaml
homebrew_installed_packages:
  - git
  - go

mas_installed_apps:
  - { id: 443987910, name: "1Password" }
  - { id: 498486288, name: "Quick Resizer" }
  - { id: 557168941, name: "Tweetbot" }
  - { id: 497799835, name: "Xcode" }

composer_packages:
  - name: hirak/prestissimo
  - name: drush/drush
    version: '^8.1'

gem_packages:
  - name: bundler
    state: latest

npm_packages:
  - name: webpack

pip_packages:
  - name: mkdocs

configure_dock: true
dockitems_remove:
  - Launchpad
  - TV
dockitems_persist:
  - name: "Sublime Text"
    path: "/Applications/Sublime Text.app/"
    pos: 5
```

Any variable can be overridden in `config.yml`; see the supporting roles' documentation for a complete list of available variables.

## Included Applications / Configuration (Default)

Applications (installed with Homebrew Cask):

  - [ChromeDriver](https://sites.google.com/chromium.org/driver/)
  - [Docker](https://www.docker.com/)
  - [Dropbox](https://www.dropbox.com/)
  - [Firefox](https://www.mozilla.org/en-US/firefox/new/)
  - [Google Chrome](https://www.google.com/chrome/)
  - [Handbrake](https://handbrake.fr/)
  - [Homebrew](http://brew.sh/)
  - [LICEcap](http://www.cockos.com/licecap/)
  - [nvALT](http://brettterpstra.com/projects/nvalt/)
  - [Sequel Ace](https://sequel-ace.com) (MySQL client)
  - [Slack](https://slack.com/)
  - [Sublime Text](https://www.sublimetext.com/)
  - [Transmit](https://panic.com/transmit/) (S/FTP client)

Packages (installed with Homebrew):

  - autoconf
  - bash-completion
  - doxygen
  - gettext
  - gifsicle
  - git
  - gh
  - go
  - gpg
  - httpie
  - iperf
  - libevent
  - sqlite
  - nmap
  - node
  - nvm
  - php
  - ssh-copy-id
  - readline
  - openssl
  - pv
  - wget
  - wrk
  - zsh-history-substring-search

My [dotfiles](https://github.com/geerlingguy/dotfiles) are also installed into the current user's home directory, including the `.osx` dotfile for configuring many aspects of macOS for better performance and ease of use. You can disable dotfiles management by setting `configure_dotfiles: no` in your configuration.

Finally, there are a few other preferences and settings added on for various apps and services.

## Full / From-scratch setup guide

Since I've used this playbook to set up something like 20 different Macs, I decided to write up a full 100% from-scratch install for my own reference (everyone's particular install will be slightly different).

You can see my full from-scratch setup document here: [full-mac-setup.md](full-mac-setup.md).

For validating this fork on clean real hardware, use the fresh Mac checklist: [real-mac-validation.md](real-mac-validation.md).

## Testing the Playbook

Many people have asked me if I often wipe my entire workstation and start from scratch just to test changes to the playbook. Nope! This project is [continuously tested on GitHub Actions' macOS infrastructure](https://github.com/geerlingguy/mac-dev-playbook/actions?query=workflow%3ACI).

You can also run macOS itself inside a VM, for at least some of the required testing (App Store apps and some proprietary software might not install properly). I currently recommend:

  - [UTM](https://mac.getutm.app)
  - [Tart](https://github.com/cirruslabs/tart)

### Clean macOS VM validation

This fork includes a reusable VM validation helper:

```bash
scripts/clean-macos-vm.sh host-check
scripts/clean-macos-vm.sh native-notes
scripts/clean-macos-vm.sh guest
scripts/clean-macos-vm.sh tart
```

`tart` mode is the most repeatable path for Apple Silicon Macs. Tart uses Apple's native Virtualization.framework under the hood, clones a clean macOS image, starts it, copies this working tree into the guest, bootstraps Homebrew and Ansible if needed, and runs the guest validation flow over SSH.

```bash
brew install openai/tools/tart
brew install cirruslabs/cli/sshpass
scripts/clean-macos-vm.sh tart
```

The default Tart image is `ghcr.io/cirruslabs/macos-sequoia-base:latest`, and the default guest credentials are `admin` / `admin`, matching the Cirrus Labs base images. Override them as needed:

```bash
scripts/clean-macos-vm.sh tart \
  --vm mac-os-playbook-test \
  --image ghcr.io/cirruslabs/macos-tahoe-base:latest \
  --user admin \
  --password admin
```

If a reused VM starts rejecting the default credentials, force a fresh clone with `--recreate`:

```bash
scripts/clean-macos-vm.sh tart --vm mac-os-playbook-test --recreate
```

By default the VM flow installs missing guest prerequisites, pre-seeds configured Homebrew taps and the dotfiles source checkout for check-mode validation, runs `ansible-galaxy`, a syntax check, and an Ansible check-mode pass with `--skip-tags mas,post`. The guest-side copy of `config.yml` excludes `openai/tools/tart` because Tart is host virtualization tooling and does not need to be installed inside Tart; override `PLAYBOOK_VM_EXCLUDED_HOMEBREW_PACKAGES` if you need a different comma-separated exclusion list. The dry run does not link those dotfiles into the guest home folder, so the `.osx` settings script is skipped until a real run creates the link; add `--real --idempotence` after the check-mode output looks safe:

```bash
scripts/clean-macos-vm.sh tart --real --idempotence
```

For VMs created directly with Apple's Virtualization.framework, VirtualBuddy, or UTM, copy or clone this repository into the guest and run the guest-side workflow:

```bash
scripts/clean-macos-vm.sh guest
scripts/clean-macos-vm.sh guest --real --idempotence
```

If the guest image has passwordless sudo configured, use `--no-become-pass` to run without the interactive become-password prompt:

```bash
scripts/clean-macos-vm.sh guest --no-become-pass --real --idempotence
```

`mas` is skipped by default because Mac App Store automation is not a reliable VM signal; test App Store installs separately on a real signed-in Mac.

## Ansible for DevOps

Check out [Ansible for DevOps](https://www.ansiblefordevops.com/), which teaches you how to automate almost anything with Ansible.

## Author

This project was created by [Jeff Geerling](https://www.jeffgeerling.com/) (originally inspired by [MWGriffin/ansible-playbooks](https://github.com/MWGriffin/ansible-playbooks)).

[badge-gh-actions]: https://github.com/geerlingguy/mac-dev-playbook/actions/workflows/ci.yml/badge.svg
[link-gh-actions]: https://github.com/geerlingguy/mac-dev-playbook/actions/workflows/ci.yml
