#!/bin/bash
#
# Re-hace el tag MP3 dependiendo del nombre del archivo y del directorio que lo contiene.
# El formato debe ser el siguiente en la jerarquia del arbol:
#
# /dir/a/mp3/ARTISTA/ANNO - ALBUM/ARTISTA - CANCION.mp3


ARTISTA=$(echo $PWD | rev | cut -d "/" -f2 | rev)
ANNO=$(echo $PWD | rev | cut -d "/" -f1 | rev | cut -d "-" -f1| tr " " "_" | cut -d "_" -f1)
ALBUM=$(echo $PWD| rev | cut -d "-" -f1| rev)


for i in *.mp3; do 
    mp3tag -r -a "$ARTISTA" \
           -l "${ALBUM/ }" \
	   -y $ANNO \
	   -e "Made in MAVE's World" \
	   -s "$(echo ${i/$ARTISTA - }| cut -d "-" -f1 | cut -d "." -f1)" \
	   "$i";
    #id3convert -1 "$i" ;
    #id3convert -p "$i" ;
	
done
