# SM64 VR Viewer

A room-scale viewer for Super Mario 64 Levels

This is made for the HTC Vive HMD *only*. Nothing against the Oculus Rift, I just don't have one yet.

To use this, you must have a Super Mario 64 USA ROM file. The file must be named "Super Mario 64 (USA).n64"
(not .zip) and be placed in the main application directory (next to M64.exe). Data is extracted from the ROM at
first start-up and cached thereafter. **You may see error messages appear in a console window on your desktop during the extraction process; this is normal, just wait and let the process complete.**

Pre-built binaries are available in the "Builds" directory. Use the "View Raw" link to download. Make sure you unzip the file in a directory you have write access to (e.g. Desktop or Documents).

## Controls

* Touchpad Press: Activate pointer
* Touchpad Release: Select menu item/teleport
* Menu Button: Return to main menu
* Grip + Trigger Buttons Together: Warp to initial spot on map

## Issues

* Currently only four maps are implemented, as each one requires some manual fiddling to look right.
* Teleporting sometimes goes through the floor.
* Random objects on maps which are not (easily) removable.
* Levels need custom floors/skyboxes to look better.
* A thousand other features which would be cool to add but aren't there yet.

## Links

Suggested background soundtrack: https://www.youtube.com/watch?v=kgVUipXiqOc

SteamVR Unity Toolkit: https://github.com/thestonefox/SteamVR_Unity_Toolkit

m64tool (level extractor): https://jul.rustedlogic.net/thread.php?id=13741

## Development Notes

You will need to install the SteamVR unity plug-in to build this project. The BMPToPNG folder contains a separate C#
project which I build with VS2010, though it could probably be easily adapted to other versions. After building it in Release
mode, copy the resulting executable to the main project directory. Its purpose is to convert the .bmp output from m64tool to
.png which Unity can ingest.
