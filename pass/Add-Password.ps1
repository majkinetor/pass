function Add-Password {
    param(
        # Path within password store
        [ValidateScript( { Test-Path -IsValid $_ } )]
        [string] $Path, 
        
        # Data to encrypt, password on the first line, whatever after it
        [Parameter(ValueFromPipeline = $true, Mandatory = $true)]
        [string] $Secret, 
        
        # Path to existing password store
        [ValidateNotNullOrEmpty()]
        [ValidateScript( {Test-Path $_} )]
        [string] $PasswordStore = "$HOME\.password-store", 
        
        # Gpg IDs used to encrypt password file, if empty use '.gpg-id' file
        [string[]] $GpgId, 
        
        # Gpg passphrase used for symetric encryption, GpgId is ignorred
        [string] $Passphrase 
    )

    $options_path = [System.IO.Path]::GetTempFileName()
    $out_file = Join-Path $PasswordStore $Path
    $out_file_dir = Split-Path $out_file
    $options = @( '--always-trust', '--yes', '--quiet', "--output $out_file.gpg")

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

    $options | % { $_.Substring(2) } | Out-File $options_path -Encoding ascii
    Write-Verbose "Gpg options file: $options_path"

    mkdir -Force $out_file_dir  | Out-Null
    $Secret | gpg --options $options_path --encrypt
}

# $password = New-PronounceablePassword -Length 20
# @"
# $password
# Username: sa
# Group: Meh
# "@ | Add-Password -Path Stage\DB\Admin -GpgId $null
# "Generated secret: $password"

Add-Password -Path Business/cheese-whiz-factory