param
(
    [string]$TFVCPath,
    [string]$LocalPath
)

function GetFileFromSourceControl($Cli, $TFVCPath, $LocalPath)
{
    $Stm = $Cli.GetItemContentAsync($null, $TFVCPath, $null, $null, $null, $null, $null, $null, [System.Threading.CancellationToken]::None).GetAwaiter().GetResult()

    $Mode = [System.IO.FileMode]::Create
    $Access = [System.IO.FileAccess]::Write
    $FStm = New-Object System.IO.FileStream -ArgumentList $LocalPath, $Mode, $Access
    $Stm.CopyTo($FStm)
    $Stm.Close()
    $FStm.Close()
}

#try
#{
    Add-Type -Assembly "Microsoft.TeamFoundation.SourceControl.WebApi"

    if(-not $LocalPath)
    {
        $LocalPath = $Env:SYSTEM_DEFAULTWORKINGDIRECTORY
        if(-not $LocalPath)
        {
            $LocalPath = "."
        }
    }

    $VSS = Get-VssConnection -TaskContext $distributedTaskContext
    $Cli = $VSS.GetClient([Microsoft.TeamFoundation.SourceControl.WebApi.TfvcHttpClient])
    $Full = [Microsoft.TeamFoundation.SourceControl.WebApi.VersionControlRecursionType]::Full
    $None = [System.Threading.CancellationToken]::None
    $Items = $Cli.GetItemsAsync($null, $TFVCPath, $Full, $false, $null, $null, $None).GetAwaiter().GetResult()
    if($Items.Count -eq 0) # Not found
    {
        Write-Error "$TFVCPath was not found"
        exit 1
    }
    elseif($Items.Count -eq 1 -and -not $Items[0].IsFolder) #It's a file
    {
        if(Test-Path $LocalPath -PathType Container) #Local path exists, and it's a folder.
        {
            $FileName = $Items[0].Path.Split("/")[-1]
            $LocalPath = [System.IO.Path]::Combine($LocalPath, $FileName)
        }
        GetFileFromSourceControl $Cli $TFVCPath $LocalPath
    }
    else #It's a folder - recurse...
    {
        if(Test-Path $LocalPath -PathType Leaf) # The target exists and it's a file
        {
            Write-Error "$LocalPath is a file, while $TFVCPath is a folder."
            exit 1
        }
        if(-not $TFVCPath.EndsWith("/"))
        {
            $TFVCPath += "/"
        }

        $BaseLen = $TFVCPath.Length
        foreach($Item in $Items)
        {
            $ItemPath = $Item.Path
            $ItemPath
            if($ItemPath.Length -gt $BaseLen) #Slightly different logic for the root
            {
                $RelPath = $ItemPath.Substring($BaseLen) #Relative TFS path, no initial /
                $RelPath = $RelPath.Replace("/", "\")
            }
            else
            {
                $RelPath = "."
            }
            $LocalItemPath = [System.IO.Path]::Combine($LocalPath, $RelPath)

            if($Item.IsFolder)
            {
                if(-not (Test-Path $LocalItemPath -PathType Container))
                {
                    "Creating $LocalItemPath"
                    New-Item -Path $LocalItemPath -ItemType Directory
                }
            }
            else # This item is a file
            {
                GetFileFromSourceControl $Cli $ItemPath $LocalItemPath
            }
        }
    }
#}
#catch
#{
#    Write-Error $_
#    exit 1
#}