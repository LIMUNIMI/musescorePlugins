# musescorePlugins
Repository for MuseScore 2.x, 3.x, and 4.x plugins developed at the Laboratorio di Informatica Musicale (LIM), Department of Computer Science, University of Milan.

## Requirements

The plugins available on this page have been developed for MuseScore version 2.0.1 or higher.

MuseScore is a free scorewriter for Windows, macOS, and Linux, supporting a wide variety of file formats and input methods. It is released as free and open-source software under the GNU General Public License.

MuseScore can be downloaded from <https://musescore.org>

## Repo content

`ExportToIEEE1599_MuseScore2_v1_1.qml` is a plugin that converts score symbols edited through MuseScore 2.x into IEEE 1599 format.

`ExportToIEEE1599_MuseScore3_v1.qml` is a plugin that converts score symbols edited through MuseScore 3.x into IEEE 1599 format.

`ExportToIEEE1599_MuseScore4_v1.qml` is a plugin that converts score symbols edited through MuseScore >4.3.2 into IEEE 1599 format. Currently there is no way to open a FolderDialog to choose the location of the exported file. FilePath must be manually entered in the appropriate TextField. E.g. "Users/testuser/Downloads" "C:/Folder1/Folder2"


`README.md` is this file.

## How to install plugins

Download the version of the plugin for your specific MueScore version.

Open MuseScore Studio.

Identify your Plugins folder via Settings > Folders > Plugins.

Copy the file to the Plugins folder

Open MuseScore Studio and activate the plugin on the Home page under the tab Plugins.

Once activated, the plugin will appear in the Plugins menu.

For more information follow the instructions at <https://musescore.org/en/handbook-advanced-topics/plugins>.

## License

EXPORT TO IEEE 1599 PLUGIN
Luca A. Ludovico - luca.ludovico@unimi.it

This program lets the user export IEEE 1599 files from MuseScore
Copyright (C) 2017, Laboratorio di Informatica Musicale

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>
