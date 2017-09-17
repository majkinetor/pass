<#
.SYNOPSIS
    Show secret from the pass store

.DESCRIPTION

#>

function Show-Secret() {
    [CmdletBinding()]
    param(
        # Path within password store
        [string] $Path, 

        # Path to existing password store, by default ~\.password-store
        [ValidateNotNullOrEmpty()]
        [ValidateScript( {Test-Path $_} )]
        [string] $PasswordStore = "$HOME\.password-store", 

        #[Parameter(ParameterSetName = 'passphrase')] 
        # Gpg passphrase used for private key access or symmetric encryption
        [string] $Passphrase, 

        # Copy secret to clipboard and clean after 45s
        [switch] $Clipboard
    )

    $secret_file = (Join-Path $PasswordStore $Path) + '.gpg'
    if (!(Test-Path $secret_file)) { throw "Secret not found: $Path" }
    
    $gpg_args = '--batch', '--yes', '--quiet'
    $gpg_args += if ($Passphrase) { '--passphrase', $Passphrase }
    $gpg_args += '--decrypt', $secret_file

    $out = gc $secret_file -Raw | gpg $gpg_args 2> $null
    if ($Clipboard) { $out | Set-Clipboard; Start-Job { sleep 45; $null | clip } } else { $out }
}

<#
.SYNOPSIS
    Add secret to the password store

.DESCRIPTION
    Add a secret to the password store and encrypt it with gpg.
    Secret can be a password or anything else. To be compatible with
    the pass password manager, if the secret contains multiple lines
    password should be on the first one. 

.EXAMPLE
    'omg so much cheese what am i gonna do' | Add-Secret Business/cheese-whiz-factory 

    Add a secret to store path Business/cheese-whiz-factory. The first .gpg-id found
    in path hierarchy is used to get the list of recipients.

.EXAMPLE
    'my secret' | Add-Secret -Path secret -Passphrase 'some password'

    Add a secret to store without using gpg recipients but encrypting it with the 
    given passphrase.

.EXAMPLE
    @"
    $(New-Password -Length 20)
    Username: admin
    "@ | Add-Secret Production\Admin -GpgId john.doe@foo.bar, admin@foo.bar

    Add a password and username as a secret, use explicit GpgIds as list of 
    recipients. New-Password is an external function that generates passwords.
#>

function Add-Secret {
    [CmdletBinding(DefaultParameterSetName = 'gpgid')]
    param(
        # Path within password store
        [ValidateScript( { Test-Path -IsValid $_ } )]
        [string] $Path, 
        
        # Data to encrypt, password on the first line, whatever after it
        [Parameter(ValueFromPipeline = $true, Mandatory = $true)]
        [string] $Secret, 
        
        # Path to existing password store, by default ~\.password-store
        [ValidateNotNullOrEmpty()]
        [ValidateScript( {Test-Path $_} )]
        [string] $PasswordStore = "$HOME\.password-store", 
        
        # Gpg IDs of recipients used to encrypt password file, if empty '.gpg-id' file is used
        [Parameter(ParameterSetName = 'gpgid')]
        [string[]] $GpgId, 

        [Parameter(ParameterSetName = 'passphrase')] 
        # Gpg passphrase used for symmetric encryption
        [string] $Passphrase 
    )

    $options_path = [System.IO.Path]::GetTempFileName()
    $out_file     = Join-Path $PasswordStore $Path
    $out_file_dir = Split-Path $out_file
    $options      = '--armor', '--always-trust', '--batch', '--yes', '--quiet', "--output $out_file.gpg"

    if ($PsCmdlet.ParameterSetName -eq 'gpgid') 
    {
        if (!$GpgId) {
            $gpg_id_dir = $out_file
            do {
                $gpg_id_dir = Split-Path $gpg_id_dir
                if (gi $gpg_id_dir\.gpg-id -ea 0) { break }    
            } while ($gpg_id_dir -ne $PasswordStore)
            
            $GpgId = gc $gpg_id_dir\.gpg-id -ea 0
            if (!$GpgId) { throw 'GpgId not specified and there are no .gpg-id files found in store' }
        }
        $GpgId | % { $options += "--recipient $_" }
    }

    $options | % { $_.Substring(2) } | Out-File $options_path -Encoding ascii
    $gpg_args = '--options', $options_path
    $gpg_args += if ($PsCmdlet.ParameterSetName -eq 'passphrase') {'--passphrase', """$Passphrase""", '--symmetric'} else {'--encrypt'} 
    Write-Verbose "gpg $gpg_args"

    mkdir -Force $out_file_dir  | Out-Null
    $Secret | gpg $gpg_args 2> $null
}

Show-Secret -Path secret -Passphrase 'some password' -Clipboard