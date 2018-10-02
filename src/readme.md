# Description

This extension provides a release task that downloads files and/or folders from Team Foundation Server version control (TFVC).
On the most basic level, the parameters specify a TFVC path and a local path, and the contents of the former
are downloaded into the latter.


It addresses a shortcoming in TFS' native facility of using source control as the source of release artifacts,
specifically, the inability to limit the download scope to a subfolder.


The task doesn't rely on workspaces. It doesn't work across team collections, the current collection is used.
It overwrites files without warning. If the target folder exists, it's not cleared before execution. If the
target folder doesn't exist and the TFVC item corresponds to a folder, the target folder will be created.


The task connects to TFS with the distributed task context, that corresponds to an artificial entity
called "Project Collection Build Service". It's not an Active Directory user, but TFS Web UI recognizes it
as a valid username, and lets one add it to groups and assign permissions to it.
