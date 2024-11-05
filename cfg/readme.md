## All configs relies on RGL's CFGs. Specifically, [rgl_base](https://github.com/RGLgg/server-resources-updater/blob/master/cfg/rgl_base.cfg) and [rgl_pt_base](https://github.com/RGLgg/server-resources-updater/blob/master/cfg/rgl_pt_base.cfg). I recommend also grabbing [rgl_off](https://github.com/RGLgg/server-resources-updater/blob/master/cfg/rgl_off.cfg).

> [!WARNING]  
> **Using [RGL's Server Resources Updater](https://github.com/RGLgg/server-resources-updater) & the pug/cup config unedited will cause the server to repeatedly change map.**
> - This is due to the rglqol.smx plugin seeing that we're changing `sv_pure`. Move that file from `tf/addons/sourcemod/plugins/rglqol.smx` to `.../plugins/disabled/rglqol.smx` (move to disabled folder) so it won't load.
> - Alternatively, you may comment out the line that has the `sv_pure 0` command in the cfg file by putting two slashes (ex. `// sv_pure "0"`) in front of it.
> - Or as another alternative, you may just download the CFGs from the RGL Server Resources repository and use those instead.
