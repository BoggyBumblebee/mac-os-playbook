# Full Mac Setup Process (for Christopher Marsh-Bourdon)

There are some things in life that just can't be automated... or aren't 100% worth the time :(

This document covers that, at least in terms of setting up a brand new Mac out of the box.

For a repeatable test pass on clean Apple hardware, follow [real-mac-validation.md](real-mac-validation.md) alongside these personal setup notes.

## Initial configuration of a brand new Mac

Before starting, I completed Apple's mandatory macOS setup wizard (creating a local user account, and optionally signing into my iCloud account). Once on the macOS desktop, I do the following (in order):

  - Install Apple's Command Line Tools: `xcode-select --install`
    - This is only the bootstrap toolchain; full Xcode is installed later by the playbook from the App Store.
  - Install Homebrew, then add it to the current shell:

    ```bash
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    eval "$(/opt/homebrew/bin/brew shellenv)"
    ```

  - Install Ansible with Homebrew: `brew install ansible`
  - Sign in to the App Store, since `mas` can't sign in automatically.
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

  - Run the syntax check: `ansible-playbook main.yml --syntax-check`
  - Run the check-mode pass:

    ```bash
    ansible-playbook main.yml --check 2>&1 | tee ~/mac-os-playbook-check.log
    ```

  - Run the real provision pass:

    ```bash
    ansible-playbook main.yml 2>&1 | tee ~/mac-os-playbook-first-run.log
    ```

    The playbook prompts for the macOS account password. The password input is hidden, so the cursor will not move while typing.

  - Run the playbook a second time to check repeatability:

    ```bash
    ansible-playbook main.yml 2>&1 | tee ~/mac-os-playbook-second-run.log
    ```

  - If there are errors, capture the failing task and log output before applying manual fixes. Then run the playbook again.
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
  - Manual settings to automate someday:
    - Finder:
      - Disable click-to-show Desktop: `defaults write com.apple.WindowManager EnableStandardClickToShowDesktop -bool false`
    - System Preferences:
      - Accessibility > Display > Reduce transparency
      - Keyboard > Keyboard Shortcuts... > Modifier Keys... > Caps Lock to Esc
      - Keyboard > Key repeat rate to 'Fast', Delay until repeat to 'Short'
      - Privacy & Security > Full Disk Access > enable "Terminal"
    - Safari:
      - View > Show Status Bar
      - Preferences > Advanced > "Show full website address"
      - Preferences > Advanced > "Show features for web developers"

## To Wrap in Post-provision automation

The following tasks have to wait for the initial Dropbox sync to complete before they'll succeed. So ideally I'll stick this all in a post-provision script but somehow flag it not to run on first provision.

```
# SSH setup.
ssh-keygen  # and create a default key to set up .ssh folder
```
