# gpx.el #

Emacs package that provides a major mode for viewing [GPX][GPX] files.

Preview: [screenshot](./screenshot.png)

The major mode displays .gpx files in a human readable format.  When the major
mode is active, the buffer displays various statistics about the file and lists
all the tracks/segments found in the file.

The displayed information includes total length, time of start/end, average
speed, max speed, etc.

It also supports drawing the routes found in the file.  You can click on a
button below a track and it will open a web browser showing that route on a
map.

You can also display elevation profile for each track.  To do that, click on
the [Toggle elevation profile] button below a track, this will insert the
elevation profile image below the track.

## Installation ##

You need to install [gpxinfo][gpxinfo] program in order to convert the files.

Additionally, if you want to be able to draw the routes on a map, in the
default way, you need to install [folium][folium].  See Configuration section
below for alternatives.

In order to display elevation profiles, you need to install
[matplotlib][matplotlib] Python library.

These dependencies can be installed on Debian-based systems with:

	sudo apt-get install gpxinfo python3-folium python3-matplotlib

You can also install them via pip:

	pip install gpx-cmd-tools folium matplotlib

## Configuration ##

If you want to show the routes inside of Emacs instead of a browser, you can
use [the OSM package][osm] and do:

    (require 'osm)
    (defun gpx-show-map-osm (file _track _segment)
      (osm-gpx-show file))
    (setq gpx-show-map-function #'gpx-show-map-osm)

Also, see the documentation of various ``gpx-*-function`` variables for more
configuration options.

## License ##

```
Copyright (C) 2024 Michał Krzywkowski

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <https://www.gnu.org/licenses/>.
```
<!-- Local Variables: -->
<!-- coding: utf-8 -->
<!-- fill-column: 79 -->
<!-- End: -->

[GPX]: https://wiki.openstreetmap.org/wiki/GPX

[gpxinfo]: https://github.com/tkrajina/gpx-cmd-tools

[folium]: https://github.com/python-visualization/folium

[matplotlib]: https://matplotlib.org/

[osm]: https://github.com/minad/osm
