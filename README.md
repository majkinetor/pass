# pass

[Pass](https://passwordstore.org) compatible Powershell module. It allows encryption of secrets using GpG in a
directory structure that is convinient to put in a repository. 

## Prerequisites

- gpg: `cinst gpg4win-vanilla`
- To advanced password generation install [MlkPwgen](https://github.com/mkropat/MlkPwgen) module: `Install-Package MlkPwgen -Force`

## Usage

First `mkdir ~\.password-store`. This is default directory and different one can be used.

```powershell

import-module pass

# Add secret
'omg so much cheese what am i gonna do' | Add-Secret Business/cheese-whiz-factory

# Generate password and add username and overwrite existing secret
(New-PronounceablePassword -Length 20), 'Username: admin' -join "`n" | Add-Secret Business/cheese-whiz-factory -Force

# Show secret and set 45s to clipboard
Show-Secret Business/cheese-whiz-factory -Clipoard

# Show directory tree
Show-Secret
```

Both symmetric and keys encryption is supported. `Add-Secret` takes recipients via `.gpg-id` files in the password store or via `$GpgId` array. It can encrypt using public keys or with passphrase instead (via`$Passphrase` argument).

There is also quick and dirty `pass` function that implements the most basic pass syntax:

```
pass insert Business/cheese-whiz-factory  
pass generate Email/jasondonenfeld.com 15  
pass Email/zx2c4.com  
```

## Notes

- For graphical interface see [pass-winmenu](https://github.com/Baggykiin/pass-winmenu). It can be installed with: `cinst pass-winmenu`.
