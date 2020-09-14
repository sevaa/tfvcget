# Description

This extension provides a build/release task that downloads files and/or folders from Azure DevOps 
legacy version control (TFVC). On the most basic level, the parameters specify a TFVC path and a local path, and
the contents of the former are downloaded into the latter.

It addresses a shortcoming in AzDevOps' native facility of using source control as the source of release artifacts,
specifically, the inability to limit the download scope to a subfolder. Also, it lets one combine
sources from Git and TFVC repositories within the same build definition.

The task doesn't rely on workspaces. It doesn't work across team collections, the current collection is used.
It overwrites files without warning. If the target folder exists, it's not cleared before execution. If the
target folder doesn't exist and the TFVC item corresponds to a folder, the target folder will be created.
If the source is a file, the target doesn't exist, and the target name ends with a directory separator (\ on Windows,
/ elsewhere), the target name will be treated a folder.

The task connects to AzDevOps with the distributed task context, that corresponds to an artificial entity
called "Project Collection Build Service". It's not an Active Directory user, but AzDevOps Web UI recognizes it
as a valid username, and lets one add it to groups and assign permissions to it.
