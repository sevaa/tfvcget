# Deliberately not parsing the manifest as JSON; want to preserve the whitespace
# Assumes the version patch # line has format: "Patch": 10
param([string]$Folder)

$Lines = Get-Content "$Folder\task.json"
$Lines = $Lines | %{ if($_ -like '*"Patch"*')
    {
        $a = $_.Split(':')
        $a[1] = [string]([int]$a[1] + 1)
        $a -join ':'
    }
    else {$_}}

$Lines | Set-Content "$Folder\task.json"