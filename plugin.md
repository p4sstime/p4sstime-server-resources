# p4sstime SourceMod Plugin

The plugin source code can be found under `scripting/`.

This plugin is licensed under the GNU GPL 3.0.

# For server hosts

This plugin was most recently tested on Metamod:Source version 1.11.0 and SourceMod version 1.11.0.6964. Make sure your server is running this version or higher for best results.

In the [releases section](https://github.com/prplnorangesoda/p4sstime-plugin/releases), you can find the .smx file associated with each release. You can insert it into `[YOURSERVERDIRECTORY]/tf/addons/sourcemod/plugins/` and it will be loaded on your SourceMod server.

# Contributing

To work on this plugin, here are the steps:

### Setting up a TF2 server

Firstly, you must set up a TF2 server in order to run the plugin. This can be hosted on your local computer through `sv_lan 1`.

1. Setting up the server:

   - Guide for Windows: https://wiki.teamfortress.com/wiki/Windows_dedicated_server
   - Guide for Linux: https://wiki.teamfortress.com/wiki/Linux_dedicated_server

2. Installing MetaMod:Source and SourceMod on the server (follow the "dedicated server" instructions): https://wiki.alliedmods.net/Installing_SourceMod_(simple)

### Working on the plugin

1. Clone the contents of the repository to the `[server]/tf/addons/sourcemod` folder.

_Note: the process from here divulges from Windows and Linux development. I personally use Mint Linux, so this guide will be written from the perspective of a similar machine._

#### Linux

2.  The compile shell script in `scripting/compile.sh` will compile all .sp files listed in `scripting/` to `plugins/`. With SourceMod, there should come an executable named `spcomp`, which will compile the plugin for you.

    - _Note: If you open this repository using VSCode, there is a "compile all plugins" task that will run this script for you._
    - Here's expected output:

    ```
     $ ./scripting/compile.sh

    	Compiling p4sstime.sp ...
    	SourcePawn Compiler 1.11.0.6964
    	Copyright (c) 1997-2006 ITB CompuPhase
    	Copyright (c) 2004-2021 AlliedModders LLC

    	p4sstime/spawnball.sp(1) : warning 242: function "Command_PasstimeSpawnBall" should return an explicit value
    	Code size: 57796 bytes
    	Data size: 21468 bytes
    	Stack/heap size: 18516 bytes
    	Total requirements: 97780 bytes

    	1 Warning.
    ```

    I've fixed the warning above, but it's left in as an example.

#### Windows

I don't have any guidance here for how to compile on Windows yet, sorry. It's compiled like a normal SourceMod plugin with includes.

---

From there on you should be set to modify the .sp files, compile the plugin, and run your SourceMod server. To hot-reload the plugin with new changes, run `sm plugins reload p4sstime` serverside (or `rcon sm plugins reload p4sstime` through rcon), and see your changes!

Note: this plugin has a _really_ strict `.gitignore`. If you add a new file outside of the `scripting/p4sstime/` folder, chances are it may not be picked up. Remember to include your new file in the `.gitignore`.
