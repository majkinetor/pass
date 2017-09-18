# pass

[Pass](https://passwordstore.org) compatible Powershell module. It allows encryption of secrets using GpG in a
directory structure that is convinient to put in a repository.  Module works cross-platfrom.

## Prerequisites

- `gpg` on the PATH: 
    - Windows: `cinst gpg4win-vanilla`
- For advanced password generation install [MlkPwgen](https://github.com/mkropat/MlkPwgen) module: `Install-Package MlkPwgen -Force`

## Usage

First `mkdir ~/.password-store`. This is default directory and different one can be used by setting `$Env:PASSWORD_STORE_DIR` variable.

```powershell

import-module pass

# Add secret
'omg so much cheese what am i gonna do' | Add-Secret Business/cheese-whiz-factory

# Generate password and add username and overwrite existing secret
"$(New-PronounceablePassword -Length 20)
Username: admin" | Add-Secret Business/cheese-whiz-factory -Force

# Show only first line of the secret (password) and set 45s to clipboard
Show-Secret Business/cheese-whiz-factory -Clipboard -FirstLine

# Show directory tree
Show-Secret

# Add anything
ps | out-string | Add-Secret ps
Show-Secret ps

    Handles  NPM(K)    PM(K)      WS(K)     CPU(s)     Id  SI ProcessName
    -------  ------    -----      -----     ------     --  -- -----------
        120       8     1488       1376     397,33   7928   1 ApMsgFwd
        132       9     1744       2428       2,88   8016   1 ApntEx
        ...
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
