import sys

import gpxpy
import matplotlib.pyplot as plt


def partial_distances(points):
    last = points[0]
    dist = 0
    for p in points:
        dist += p.distance_2d(last)
        last = p
        yield dist


filename = sys.argv[1]
track = int(sys.argv[2])
segment = int(sys.argv[3])
output_filename = sys.argv[4]

with open(filename, 'r') as f:
    gpx = gpxpy.parse(f)

track_data = gpx.tracks[track]
segment_data = track_data.segments[segment]
elevation = [p.elevation or 0 for p in segment_data.points]
distance_travelled = list(partial_distances(segment_data.points))

fig, ax = plt.subplots(figsize=(9, 3))
plt.fill_between(distance_travelled, elevation)
ax.xaxis.set_major_formatter(lambda x, _: f'{x/1000:g}km')
ax.yaxis.set_major_formatter(lambda x, _: f'{x:g}m')
plt.ylim(min(elevation), max(elevation))
plt.savefig(output_filename, dpi=100)
