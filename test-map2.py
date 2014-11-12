# brew install matplotlib matplotlib.basemap numpi PyYAML PIL
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
#m = Basemap(projection='merc',\
#			llcrnrlat=-68,\
#            llcrnrlon=-170,\
#            urcrnrlat=75,\
#            urcrnrlon=192,\
#            lat_ts=20,\
#            resolution='l')

m = Basemap(projection='robin',lon_0=0, resolution='l')

# Draw topography (doesn't look very good to be honest)
#m.etopo()

# Draw gray continents. Fill lake with same color as water.
#m.fillcontinents(color='#e9e9c9', lake_color='#b2d0ff', ax=None, zorder=None, alpha=None)
m.fillcontinents(color='0.75', lake_color='white', ax=None, zorder=None, alpha=None)
#m.drawmapboundary(fill_color='#b2d0ff', zorder=None)
#m.drawmapboundary(color='k', linewidth=0.1, fill_color=None, zorder=None, ax=None)

# Draw relief (better than etopo), then we change water color
#m.shadedrelief()
#m.drawlsmask(ocean_color='#b2d0ff',land_color=(255,255,255,0.8))

# draw countries and boundaries
m.drawcoastlines(linewidth=0.1, linestyle='solid', color='k', antialiased=True)
m.drawcountries(linewidth=0.2, linestyle='solid', color='k', antialiased=True)

# draw parallels and meridians.
m.drawparallels(np.arange(-90.,91.,10.), linewidth=0.15, zorder=None)
m.drawmeridians(np.arange(-180.,181.,10.), linewidth=0.15, zorder=None)

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

# Higher zorder so it can be always on the top front layer.
m.plot(x,y,'b8', markersize=8, zorder=20)

plt.title("L-Root Presence")
plt.show()

