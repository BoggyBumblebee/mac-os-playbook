# Full Mac Setup Process (for Christopher Marsh-Bourdon)

There are some things in life that just can't be automated... or aren't 100% worth the time :(

This document covers that, at least in terms of setting up a brand new Mac out of the box.

For a repeatable test pass on clean Apple hardware, follow [real-mac-validation.md](real-mac-validation.md) alongside these personal setup notes.

## Initial configuration of a brand new Mac

Before starting, I completed Apple's mandatory macOS setup wizard (creating a local user account, and optionally signing into my iCloud account). Once on the macOS desktop, I do the following (in order):

  - Install Apple's Command Line Tools: `xcode-select --install`
    - This is only the bootstrap toolchain; full Xcode is installed later by the
      playbook from the App Store.
    - After MAS installs full Xcode, the playbook selects it and accepts the
      Xcode license before Dock configuration continues.
  - If I installed or selected full Xcode outside this playbook and want to
    accept its license manually:

    ```bash
    sudo xcodebuild -license accept
    ```

    On a clean Mac with only Command Line Tools selected, that command can
    report that `xcodebuild` requires Xcode. That is OK; continue with Homebrew.

  - Install Homebrew, then add it to the current shell:

    ```bash
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    eval "$(/opt/homebrew/bin/brew shellenv)"
    ```

  - Install Ansible with Homebrew: `brew install ansible`
  - Sign in to the App Store, since `mas` can't sign in automatically.
  - If this Mac's profile removes App Store apps, allow the terminal app before
    the real playbook run:
    - Open System Settings > Privacy & Security > App Management.
    - Enable `Terminal.app`, or the exact terminal app that will run the
      playbook.
    - Quit and reopen that terminal app.
    - If macOS still blocks app removal, also enable the same terminal app under
      Full Disk Access, then quit and reopen it again.
  - Clone mac-os-playbook to the Mac:

    ```bash
    git clone https://github.com/BoggyBumblebee/mac-os-playbook.git
    cd mac-os-playbook
    ```

  - Install the Ansible Galaxy dependencies: `ansible-galaxy install -r requirements.yml`
  - Confirm the machine profile. The playbook looks for
    `config/machines/<profile>.yml`, where `<profile>` defaults to the Mac's
    Ansible hostname. If needed, pass the profile explicitly before running
    syntax, check-mode, or real provision commands:

    ```bash
    export PLAYBOOK_MACHINE_PROFILE=MacBookAirM2
    ```

  - Run the syntax check: `scripts/run-playbook.sh --syntax-check`
  - Run the check-mode pass:

    ```bash
    scripts/run-playbook.sh --check --log ~/mac-os-playbook-check.log
    ```

  - Run the real provision pass:

    ```bash
    scripts/run-playbook.sh --log ~/mac-os-playbook-first-run.log
    ```

    The runner prompts for the macOS account password before Ansible starts.
    The password input is hidden, so the cursor will not move while typing.
    Logs use Ansible `-v` output by default, and check mode includes `--diff`.
    If full Xcode has been installed but its license is blocking developer
    tools, the runner accepts the license before Ansible starts.

  - Run the playbook a second time to check repeatability:

    ```bash
    scripts/run-playbook.sh --log ~/mac-os-playbook-second-run.log
    ```

  - If there are errors, capture the failing task and log output before applying manual fixes. Then run the playbook again.
  - The playbook clones the dotfiles repository if needed, but it does not update
    an existing dotfiles checkout by default. Pull or commit dotfiles changes in
    that repository separately.
  - Start Synchronization tasks:
    - Open Photos and make sure iCloud sync options are correct
    - Open Music, make sure computer is authorized, and set Library sync options
    - Open Dropbox, sign in, and set up sync if this Mac uses Dropbox-backed configuration.
  - Install old-fashioned apps:
    - Install Blackmagic Tools...
      - Media Express
      - Desktop Video Setup
      - LiveKey
    - Sign into Microsft 365 for Office to Work
    - Sign into Adobe Creative Cloud for Adobe Acrobat to work
    - Sign into JetBrains Toolbox and install...
      - DataGrip
      - Fleet
      - GoLand
      - IntelliJ
      - PyCharm
      - RubyMine
      - RustRover
      - WebStorm
  - These things might be automatable, but I do them manually right now:
    - Configure Time Machine backup drive
    - Install VPN configurations if needed
  - Manual settings that cannot be handled reliably with `defaults`:
    - Keyboard > Keyboard Shortcuts... > Modifier Keys... > Caps Lock to Esc
    - Apple ID, iCloud, Find My, Touch ID, and Apple Pay setup
    - Privacy & Security > App Management > enable `Terminal.app`, or the
      exact terminal app running the playbook, before profiles that remove MAS
      apps
    - Privacy & Security > Full Disk Access > enable the same terminal app if
      MAS app removal is still blocked

## To Wrap in Post-provision automation

The following tasks have to wait for the initial Dropbox sync to complete before they'll succeed. So ideally I'll stick this all in a post-provision script but somehow flag it not to run on first provision.

```
# SSH setup.
ssh-keygen  # and create a default key to set up .ssh folder
```
