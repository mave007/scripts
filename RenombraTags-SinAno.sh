#!/bin/bash
#
# Re-hace el tag MP3 dependiendo del nombre del archivo y del directorio que lo contiene.
# El formato debe ser el siguiente en la jerarquia del arbol:
#
# /dir/a/mp3/ARTISTA/ALBUM/ARTISTA - N_pista - CANCION.mp3

# mp3tag [-a <artist>] 
#        [-s <songname>] 
#        [-l <album>] 
#        [-y <year>] 
#        [-e etcetera] 
#        [-g genre] 
#        [-k track]

#set +e
#set +x

ARTISTA=$(echo $PWD | rev | cut -d "/" -f2 | rev)
ALBUM=$(echo $PWD| rev | cut -d "/" -f1| rev)


for i in *.mp3; do 
    mp3tag -r \
           -a "$ARTISTA" \
	   -s "$(echo ${i/$ARTISTA - ?? -} | cut -d "." -f1)" \
           -l "$ALBUM" \
	   -e "Made in MAVE's World" \
	   -k $(echo ${i/$ARTISTA - }| cut -d "-" -f1) "$i";
    id3convert -1 $i ;
    id3convert -p $i ;
	
done
