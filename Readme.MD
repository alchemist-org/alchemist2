# Alchemist 2

[![License: GPL v2](https://img.shields.io/badge/License-GPLv2-blue.svg)](https://www.gnu.org/licenses/old-licenses/gpl-2.0.en.html)
![Badge](https://hitscounter.dev/api/hit?url=https%3A%2F%2Fgithub.com%2Falchemist-org%2Falchemist2&label=Visitors&icon=suit-heart-fill&color=%23e35d6a)

A lightweight terminal entry point / status provider for all projects managed by git. Start the day with it when opening projects locally, and end the day with it when checking everything is pushed.

![Preview](preview.png)

## Requirements

- jq (`sudo apt -y install jq`)

## Features

Anywhere in terminal for all projects:

- Open new terminal tab for choosed one, jump there and activate conda env
- Show uncommitted changes
- Show committing users info
- Show every upload destination
- Show committed changes for past time interval (1d is default)
- Init locally newly created repo on website
- Clone all or selected user, org repos in bulk

Implemented support is for github and gitlab.

## Usage

```
## Are repos correctly set up? Is something not commited? 
$ gitstatus --urls --names

## What was commited for past 3 days?
$ gitstatus --logs 3d

## Set name and mail for projects in work
$ gitconfig ~/ccp-projects --name "Lukas Drahnik" --mail "lukas.drahnik@img.cas.cz"

## Init single repo, neccessary to create repo on both websites first
$ gitclone ~/ccp-projects --all git@github.com:alchemist-org/test.git --push ssh://git@codex.img.cas.cz:2816/ccp/bioinfo/test.git

## Clone org repos
$ gitclone ~/asus-linux-drivers-test --org https://github.com/asus-linux-drivers
$ gitclone ~/asus-linux-test --org https://gitlab.com/asus-linux

## Clone user repos
$ gitclone ~/test-ldrahnik --user https://github.com/ldrahnik

## Clone org or user repos with prefixed backup destination (wildcard is repo name)
$ gitclone ~/test-asus-linux-drivers --org https://github.com/asus-linux-drivers --push git@github.com:ldrahnik/asus-linux-backup-*

## Jump to the project and activate penv, conda
$ gitstatus zf
```

## Installation

Add to `~/.bashrc`:

```
# >>> alchemist2 initialize >>>
# prepared terminal
export ALCHEMIST_TERMINAL_CMD="io.elementary.terminal --new-tab --working-directory"

# prepared users
export ALCHEMIST_CODEX_USER_NAME="Lukas Drahnik"
export ALCHEMIST_CODEX_USER_MAIL="lukas.drahnik@img.cas.cz"
export ALCHEMIST_GITHUB_USER_NAME="Lukas Drahnik"
export ALCHEMIST_GITHUB_USER_MAIL="ldrahnik@gmail.com"

# aliases
alias gitstatus='bash ~/projects/alchemist2/gitstatus.sh'
alias gitconfig='bash ~/projects/alchemist2/gitconfig.sh'
alias gitclone='bash ~/projects/alchemist2/gitclone.sh'

# aliases of aliases
alias gitusers='bash ~/projects/alchemist2/gitstatus.sh --users'
alias giturls='bash ~/projects/alchemist2/gitstatus.sh --urls'
alias gitlogs='bash ~/projects/alchemist2/gitstatus.sh --logs'
# <<< alchemist2 initialize <<<
```
