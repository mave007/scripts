# brew install matplotlib matplotlib.basemap numpi PyYAML
#
from mpl_toolkits.basemap import Basemap
import numpy as np
import matplotlib.pyplot as plt
import matplotlib.cm as cm
import yaml

#fig = plt.figure(figsize=(8, 4.5))
fig = plt.figure(figsize=(24, 13.5))
#fig = plt.figure(figsize=(48, 27))

# llcrnrlat,llcrnrlon,urcrnrlat,urcrnrlon
# are the lat/lon values of the lower left and upper right corners
# of the map.
# lat_ts is the latitude of true scale.
# resolution = 'c' means use crude resolution coastlines.
#m = Basemap(projection='merc',llcrnrlat=-58,urcrnrlat=75,\
#            llcrnrlon=-170,urcrnrlon=192,lat_ts=20,resolution='l')

m = Basemap(projection='robin',lon_0=0, resolution='l')

m.drawcoastlines(linewidth=0.1, linestyle='solid', color='k', antialiased=True)
m.drawcountries(linewidth=0.1, linestyle='solid', color='k', antialiased=True)
m.drawmapboundary(color='k', linewidth=0.1, fill_color=None, zorder=None, ax=None)
#m.drawlsmask(land_color='0.8', ocean_color='w',lakes=False)
#m.fillcontinents(color='coral',lake_color='aqua')
m.fillcontinents(color='0.85', lake_color=None, ax=None, zorder=None, alpha=None)

# draw parallels and meridians.
m.drawparallels(np.arange(-90.,91.,10.), linewidth=0.15, zorder=0)
m.drawmeridians(np.arange(-180.,181.,10.), linewidth=0.15, zorder=0)

data=open('l-root.yml','r')
rawdata=yaml.load(data)

lat=[]
lon=[]
for instance in rawdata["Instances"]:
    for key,value in instance.iteritems():
        if ( key == "Latitude" ):
            lat.append(float(value))
        if ( key == "Longitude" ):
            lon.append(float(value))

x,y = m(lon,lat)

m.plot(x,y,'b8', markersize=5, zorder=2)

#m.drawmapboundary(fill_color='aqua')
#plt.title("L-Root Presence")
plt.show()

