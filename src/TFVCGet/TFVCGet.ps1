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

function EnsureFolderExistence($Path)
{
    if(-not [System.IO.Directory]::Exists($Path))
    {
        "Creating $Path"
        New-Item -Path $Path -ItemType Directory
    }
}

function MakeLocalPath($TFVCPath, $LocalPath, $BaseLen)
{
    $RelPath = $TFVCPath.Substring($BaseLen) # Relative TFS path, no initial /
    $RelPath = $RelPath.Replace("/", "\")
    [System.IO.Path]::Combine($LocalPath, $RelPath)    
}

# The zeroth element is the folder itself, the rest is files and subfolders
# Assuming the folder already exists
# LocalPath and BaseLen are task parameters
function GetFolderFromSourceControl($Items, $FolderQueue, $LocalPath, $BaseLen)
{
    foreach($Item in $Items)
    {
        $ItemPath = $Item.Path
        if($ItemPath -ne $Items[0].Path)
        {
            $LocalItemPath = MakeLocalPath $ItemPath $LocalPath $BaseLen

            if($Item.IsFolder) # The root folder already exists, subfolders of root will be queued
            {
                $FolderQueue.Enqueue($Item)
            }
            else # This item is a file
            {
                $ItemPath
                GetFileFromSourceControl $Cli $ItemPath $LocalItemPath
            }
        }
        else
        {
            $ItemPath
        }
    }
}

try
{
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
    $OneLevel = [Microsoft.TeamFoundation.SourceControl.WebApi.VersionControlRecursionType]::OneLevel
    $None = [System.Threading.CancellationToken]::None
    $Items = $Cli.GetItemsAsync($null, $TFVCPath, $OneLevel, $false, $null, $null, $None).GetAwaiter().GetResult()
    if($Items.Count -eq 0) # Not found
    {
        Write-Error "$TFVCPath was not found"
        exit 1
    }
    elseif($Items.Count -eq 1 -and -not $Items[0].IsFolder) #It's a file
    {
        if([System.IO.Directory]::Exists($LocalPath)) #Local path exists, and it's a folder.
        {
            $FileName = $Items[0].Path.Split("/")[-1]
            $LocalPath = [System.IO.Path]::Combine($LocalPath, $FileName)
        }
        GetFileFromSourceControl $Cli $TFVCPath $LocalPath
    }
    else #It's a folder - recurse...
    {
        if([System.IO.File]::Exists($LocalPath)) # The target exists and it's a file
        {
            Write-Error "$LocalPath is a file, while $TFVCPath is a folder."
            exit 1
        }

        # For easier production of relative paths
        if(-not $TFVCPath.EndsWith("/"))
        {
            $TFVCPath += "/"
        }

        $BaseLen = $TFVCPath.Length
        EnsureFolderExistence $LocalPath
        $FolderQueue = New-Object "System.Collections.Generic.Queue[Microsoft.TeamFoundation.SourceControl.WebApi.TfvcItem]"
        GetFolderFromSourceControl $Items $FolderQueue $LocalPath $BaseLen

        while($FolderQueue.Count -gt 0)
        {
            $Folder = $FolderQueue.Dequeue()
            $FolderLocalPath = MakeLocalPath $Folder.Path $LocalPath $BaseLen
            EnsureFolderExistence $FolderLocalPath
            $Items = $Cli.GetItemsAsync($null, $Folder.Path, $OneLevel, $false, $null, $null, $None).GetAwaiter().GetResult()
            GetFolderFromSourceControl $Items $FolderQueue $LocalPath $BaseLen
        }
    }
}
catch
{
    Write-Error $_
    exit 1
}