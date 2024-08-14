# Cleanup CLI

Cleanup CLI is a CLI tool written in Zig that allows for rudimentary file management from the terminal.
Allowing for renaming and deleting of both files and directories, this tool is another step towards never using the file explorer ever again.

## Usage

After adding the binary to your PATH variable, it can be used like so.

`cleanup [directory]`

Where `directory` is a optional path from the current working directory.
This field can also be left blank to operate on the current working directory.

By default, this tool only operates on files. In order to delete directories, add the `--all` flag or `-a`.
By default, this tool asks what to do with every single file it encounters. In order to specify that you'd like to only delete some subset of files in the directory, you can add the `--delete` flag or `-d`.

That's pretty much it. Hard to mess up, but not impossible :) 
