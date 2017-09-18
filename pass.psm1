<#
.SYNOPSIS
    Remove secret from the password store
#>

function Remove-Secret() {
    [CmdletBinding()]
    param(
        # Path within password store to be removed
        [string] $Path, 

        # Path to existing password store, by default ~\.password-store
        [ValidateNotNullOrEmpty()]
        [ValidateScript( {Test-Path $_} )]
        [string] $PasswordStore = $Env:PASSWORD_STORE_DIR
    )
    if ('.','\.','/.' -contains $Path.Trim()) { throw 'Can not remove entire password store' }
    if ($Path -match '\.\.') { throw 'Can not use .. when removing' }

    $secret_file = Join-Path $PasswordStore $Path
    if ((gi $secret_file) -isnot [System.IO.DirectoryInfo]) { $secret_file += '.gpg' }

    rm -Force -Recurse $secret_file
}

<#
.SYNOPSIS
    Show secret from the pass store

.DESCRIPTION
    Show encrypted secret on console. Use passphrase if private key
    or symmetric encryption require it.

    Called without any parameters it shows tree of the password store
#>

function Show-Secret() {
    [CmdletBinding()]
    param(
        # Path within password store
        [string] $Path, 

        # Path to existing password store, by default $Env:PASSWORD_STORE_DIR
        [ValidateNotNullOrEmpty()]
        [ValidateScript( {Test-Path $_} )]
        [string] $PasswordStore = $Env:PASSWORD_STORE_DIR, 

        #[Parameter(ParameterSetName = 'passphrase')] 
        # Gpg passphrase used for private key access or symmetric encryption
        [string] $Passphrase, 

        # Copy secret to clipboard and clean after 45s
        [switch] $Clipboard, 

        # Return only first line from the secret
        [switch] $FirstLine
    )

    if (!$Path) {
        tree.com /F $PasswordStore; return
    }

    $secret_file = (Join-Path $PasswordStore $Path) + '.gpg'
    if (!(Test-Path $secret_file)) { throw "Secret not found: $Path" }
    
    $gpg_args = '--batch', '--yes', '--quiet'
    $gpg_args += if ($Passphrase) { '--passphrase', $Passphrase }
    $gpg_args += '--decrypt', $secret_file

    $out = gc $secret_file -Raw | gpg $gpg_args 2> $null
    if ($FirstLine) { $out = $out | select -First 1}

    if ($Clipboard) { 
        $out | clip
        Remove-Job pass -ea 0 -Force
        Start-Job -Name pass { sleep 45; $null | clip } 
    } 
    else { $out }
}
sal Get-Secret Show-Secret

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
        [Parameter(Position=1, Mandatory = $true)]
        [string] $Path, 
        
        # Data to encrypt, password on the first line, whatever after it
        [Parameter(ValueFromPipeline = $true, Mandatory = $true)]
        [string] $Secret, 
        
        # Path to existing password store, by default $Env:PASSWORD_STORE_DIR
        [ValidateNotNullOrEmpty()]
        [ValidateScript( {Test-Path $_} )]
        [string] $PasswordStore = $Env:PASSWORD_STORE_DIR,
        
        # Gpg IDs of recipients used to encrypt password file, if empty '.gpg-id' file is used
        [Parameter(ParameterSetName = 'gpgid')]
        [string[]] $GpgId, 

        [Parameter(ParameterSetName = 'passphrase')] 
        # Gpg passphrase used for symmetric encryption
        [string] $Passphrase, 

        # Use to overwrite existing secrets
        [switch] $Force
    )

    $options_path = [System.IO.Path]::GetTempFileName()
    $out_file     = (Join-Path $PasswordStore $Path) + '.gpg'
    $out_file_dir = Split-Path $out_file
    $options      = '--armor', '--always-trust', '--batch', '--yes', '--quiet', "--output $out_file"

    if ((Test-Path $out_file) -and !$Force) { throw 'Secret already exists. Use Force to overwrite' }

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

    New-Item -ItemType Directory -Force $out_file_dir  | Out-Null
    $Secret | gpg $gpg_args
    if (!$?) { throw "Gpg exit code: $LastExitCode" }
}

<#
.SYNOPSIS
   Simulates pass linux password manager
.LINK
    https://passwordstore.org
#>
function Use-Pass() {
    if ($args.Count -gt 0) {$cmd = $args[0]}
    
    if ($cmd -eq 'insert') {
        Add-Secret $args[1]
        return
    }

    if ($cmd -eq 'generate') {
        [Reflection.Assembly]::LoadWithPartialName("System.Web") | Out-Null
        $len = if ($args[2]) {$args[2]} else {15}
        [System.Web.Security.Membership]::GeneratePassword($len, 2) | Add-Secret $args[1]
        return
    }

    if ($cmd -eq 'rm') { Remove-Secret $args[1]; return }

    Show-Secret $cmd
}
sal pass Use-Pass

$ErrorActionPreference = 'Continue' # gpg warnings fail scritps when EA is stop.

if (!$Env:PASSWORD_STORE_DIR) { $Env:PASSWORD_STORE_DIR = Join-Path $HOME '.password-store' }

Write-Host -Foreground green "Using password store:" $Env:PASSWORD_STORE_DIR