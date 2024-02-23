# Full Mac Setup Process (for Christopher Marsh-Bourdon)

There are some things in life that just can't be automated... or aren't 100% worth the time :(

This document covers that, at least in terms of setting up a brand new Mac out of the box.

## Initial configuration of a brand new Mac

Before starting, I completed Apple's mandatory macOS setup wizard (creating a local user account, and optionally signing into my iCloud account). Once on the macOS desktop, I do the following (in order):

  - Install Ansible (following the guide in [README.md](README.md))
  - Install Brew, so we don't have to re-run Ansible twice (bug in existing code base)
  - **Sign in in App Store** (since `mas` can't sign in automatically)
  - Clone mac-dev-playbook to the Mac: `git clone git@github.com:boggybumblebee/mac-os-playbook.git`
  - Drop `config.yml` from your backup to the playbook (copy over the network or using a USB flash drive).
  - Run the playbook with `--skip-tags post`.
    - If there are errors, you may need to finish up other tasks like installing 'old-fashioned' apps first (since I try to place Photoshop in the Dock and it can't be installed automatically). Then, run the playbook again ;)
  - Start Synchronization tasks:
    - Open Photos and make sure iCloud sync options are correct
    - Open Music, make sure computer is authorized, and set Library sync options
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

## To Wrap in Post-provision automation

The following tasks have to wait for the initial Dropbox sync to complete before they'll succeed. So ideally I'll stick this all in a post-provision script but somehow flag it not to run on first provision.

```
# SSH setup.
ssh-keygen  # and create a default key to set up .ssh folder
