# groupify

This is a simple shell command, written in OCaml, that makes it a bit easier
to work with a group of users in a shared filesystem. It recursively descends
into a directory making every file group-owned and group-writable and sets the
setgid bit on directories so that new files and directories automatically
inherit the same group.

Type "make" to build. Run "groupify -h" or "groupify" with no parameters for
usage. groupify requires extlib to compile, and is designed to run on Linux.
