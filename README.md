# CMSC435 Fishtank Viewer
Viewer for the [CMSC 435 boids assignment](https://redirect.cs.umbc.edu/~adamb/435.s24/proj6.html)

Visualizes the .out file containing the boids and food, with an interactable timeline. 

**Note:** If you are having troubles with vulkan, read through [this section](#vulkan-errors) for how to run it in opengl compatibility mode.

## Running
### Windows/Linux
For running on windows and linux, you just need to run the relevant executable [in the releases section](https://github.com/ardahl/CMSC435-Fishtank-Viewer/releases/latest) by double clicking it or from the terminal. With it open, you can click on the Open File button to load the output file. If you make changes to the file, you can hit the Reload button to refresh. 

### macOS
For mac, I don't have the ability to sign the app so the first time you run it will fail and it will show a security message. You will then need to open System Preference -> Security & Privacy, and there will be an 'Allow' button somewhere on that page for the fishtank app.

## Input
The input format is simple. The first line is the number of frames, nframes. This is followed by nframes of frame data. 

Each frame consists of both boids and food. The first line of a boid segment contains the number of boids, nboids, followed by nboids lines with position and velocity. The food segment has the number of pieces of food, nfood, followed by nfood lines with just the food position. Any line that starts with '#' will be skipped. [Sample.out](sample.out) shows and example of what the format is like.

### Extension
Extra data can be put at the end of the lines with data (after the velocity for the boids and after the position for food) which will not be parsed, but is available if you want to extend the viewer with anything. One extension is already included as an example, if you add an extra 3d vector at the end of a line and each value is between 0 and 1 (ex. [0, 1, 0.5]) that will override the color of that boid/food.

## Settings
There are a couple of options available in the settings button in the upper left.

* FPS  
This opens a separate dialog box where you can input the framerate the app runs at. This sets the framerate of the entire program, not just the playback speed (this can't be done easily since there's no guarantee that the same fish and food stay on the same lines), so setting it low will make the whole thing laggy. Hovering over the text field shows what the max value is, which is dependent of the refresh rate of the monitor. Defaults to 60 fps.
* Color Out-Of-Bounds Fish  
Toggling this on will change the color of the fish that are outside of the [-0.5,0.5]x[-0.25,0.25]x[-0.125,0.125] boundaries from green to red for each frame that they are outside. On by default.
* Tank Walls  
Turns on or off the colored walls of the tank. On by default.
* Lock Camera  
With this on, the camera is fully locked in place and can't be changed. When off, you can scroll up and down to zoom in and out, and moving the mouse while holding right click will rotate the camera around the tank. On by default.

## Vulkan Errors

### Windows/Linux

Depending on your system there may be issues with vulkan. In that case there is an opengl compatibility render mode available. To run in this mode, navigate to the location of the executable in the terminal and run the command: 

`./Fishtank --rendering-driver opengl3`

replacing 'Fishtank' with whatever the name of the executable is. 

### macOS

Applications are packaged differently on mac into a folder, not a file, and so the command is a bit different. There are details in the Note section at the top of [this page](https://docs.godotengine.org/en/stable/tutorials/editor/command_line_tutorial.html), but the gist is that from the Applications folder the command becomes the following:

`./Fishtank.app/Contents/MacOS/Fishtank --rendering-driver opengl3`
