var tl = require("vsts-task-lib");
var vso = require("vso-node-api");
var fs = require("fs");
var path = require("path");
var OneLevel = 1;

async function getFileFromSourceControl(cli, TFVCPath, LocalPath)
{
    var ins = await cli.getItemContent(TFVCPath);
    ins.pipe(fs.createWriteStream(LocalPath));
}

function ensureFolderExistence(Path)
{
    if(!tl.exist(Path))
        fs.mkdirSync(Path, {recursive:true});
}

function makeLocalPath(TFVCPath, LocalPath, BaseLen)
{
    var RelPath = TFVCPath.substr(BaseLen);
    if(path.sep != "/")
        RelPath = RelPath.replace("/", path.sep);
    return path.join(LocalPath, RelPath);
}

async function getFolderFromSourceControl(cli, Items, FolderQueue, LocalPath, BaseLen)
{
    var BaseTFVCPath = Items.reduce((min, it) => it.path.length < min.path.len ? it : min, Items[0]).path;
    console.log(BaseTFVCPath);
    for(var i=0;i<Items.length;i++)
    {
        var Item = Items[i];
        var ItemPath = Item.path;
        if(ItemPath != BaseTFVCPath)
        {
            var LocalItemPath = makeLocalPath(ItemPath, LocalPath, BaseLen);
            if(Item.isFolder)
            {
                tl.debug("Enqueueing " + ItemPath);
                FolderQueue.push(Item);
            }
            else //It's a file
            {
                console.log(ItemPath);
                await getFileFromSourceControl(cli, ItemPath, LocalItemPath);
            }
        }
    }
}

async function main()
{
    try
    {
        var conn;
        var TFVCPath, LocalPath;
        
        if(tl.getVariable("Agent.Version")) //Running from the agent
        {
            //Use the context connection - effectively the "Project Collection Build Service"
            var url = tl.getEndpointUrl("SYSTEMVSSCONNECTION", false);
            var token = tl.getEndpointAuthorizationParameter("SYSTEMVSSCONNECTION", "AccessToken", false);
            conn = vso.WebApi.createWithBearerToken(url, token, null);

            TFVCPath = tl.getInput("TFVCPath");
            LocalPath = tl.getInput("LocalPath"); 
        }
        else //Interactive run
        {
            //TFS context passed through the environment variables - TFSURL and PAT
            conn = new vso.WebApi(process.env.TFSURL, vso.getPersonalAccessTokenHandler(process.env.PAT));

            //Parameters passed through the node.js command line
            TFVCPath = process.argv[2];
            LocalPath = process.argv[3];
        }
        cli = await conn.getTfvcApi();

        if(!LocalPath)
        {
            LocalPath = tl.getVariable("System.DefaultWorkingDirectory");
            if(!LocalPath)
                LocalPath = ".";
        }

        var Items = await cli.getItems(null, TFVCPath, OneLevel, false, null);
        if(!Items.length)
        {
            tl.error(TFVCPath + " was not found");
            process.exit(1);
        }
        else if(Items.length == 1 && !Items[0].isFolder) //It's a file
        {
            if(tl.exist(LocalPath) && fs.statSync(LocalPath, {bigint:false}).isDirectory())
            {
                var FileName = Items[0].path.split("/").pop();
                LocalPath = path.join(LocalPath, FileName);
            }
            await getFileFromSourceControl(cli, TFVCPath, LocalPath);
        }
        else //It's a folder - recurse...
        {
            if(tl.exist(LocalPath) && fs.statSync(LocalPath, {bigint:false}).isFile())
            {
                tl.error(LocalPath + " is a file, while " + TFVCPath + " is a folder.");
                process.exit(1);
            }

            // For easier production of relative paths
            if(!TFVCPath.endsWith("/"))
                TFVCPath += "/";
            var BaseLen = TFVCPath.length;
            ensureFolderExistence(LocalPath);
            var FolderQueue = [];
            await getFolderFromSourceControl(cli, Items, FolderQueue, LocalPath, BaseLen);

            while(FolderQueue.length)
            {
                var Folder = FolderQueue.shift();
                var FolderPath = Folder.path;
                tl.debug("Dequeued " + FolderPath);
                var FolderLocalPath = makeLocalPath(FolderPath, LocalPath, BaseLen);
                ensureFolderExistence(FolderLocalPath);
                Items = await cli.getItems(null, FolderPath, OneLevel);
                await getFolderFromSourceControl(cli, Items, FolderQueue, LocalPath, BaseLen);
            }
        }
    }
    catch(exc)
    {
        tl.error(exc.message);
        process.exit(1);
    }
}

main();

