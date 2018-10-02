# Deliberately not parsing the manifest as JSON; want to preserve the whitespace
param([string]$File = "ext.json")

$Lines = Get-Content $File
$Lines = $Lines | %{ if($_ -like '*"version"*')
    {
        $a = $_.Split('"')
        $v = $a[3].Split(".")
        $v[2] = [string]([int]$v[2] + 1)
        $a[3] = $v -join '.'
        $a -join '"'
    }
    else {$_}}

$Lines | Set-Content $File