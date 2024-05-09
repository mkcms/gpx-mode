import sys

import folium
import gpxpy

route_map = folium.Map(location=None,
                       tiles='OpenStreetMap',
                       width=1024,
                       height=768)

filename = sys.argv[1]
track = int(sys.argv[2])
segment = int(sys.argv[3])
output_filename = sys.argv[4]

with open(filename, 'r') as f:
    gpx = gpxpy.parse(f)

track_data = gpx.tracks[track]
segment_data = track_data.segments[segment]

coordinates = [(p.latitude, p.longitude) for p in segment_data.points]

folium.PolyLine(coordinates, weight=6).add_to(route_map)

route_map.fit_bounds(coordinates)

route_map.save(output_filename)
