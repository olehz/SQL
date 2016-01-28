#!/bin/bash
HASHMEM=8000
REGION='UA'
MAXMERGE=5

#Check directories
if [ ! -d data ]; then
	mkdir -p data
else
	rm data/change_file*
fi

if [ ! -d data/cache ]; then
	mkdir -p data/cache
fi

if [ ! -d data/osmupdate_temp ]; then
	mkdir -p data/osmupdate_temp
fi

#Download planet.osm.pbf
if [ ! -f data/planet-latest.osm.pbf ]; then
    aria2c -R --allow-piece-length-change=true --file-allocation=none --uri-selector=inorder http://planet.osm.org/pbf/planet-latest.osm.pbf http://ftp5.gwdg.de/pub/misc/openstreetmap/planet.openstreetmap.org/pbf/planet-latest.osm.pbf http://ftp.heanet.ie/mirrors/openstreetmap.org/pbf/planet-latest.osm.pbf ftp://ftp.spline.de/pub/openstreetmap/pbf/planet-latest.osm.pbf -odata/planet-latest.osm.pbf
    #Filter
    if ! osmconvert data/planet-latest.osm.pbf --verbose -B=config/poly/$REGION.poly --complex-ways --drop-version -o=data/local.o5m --hash-memory=$HASHMEM; then
        echo "Cut error"
        exit
    fi
fi

if ! osmupdate data/local.o5m --max-merge=$MAXMERGE --tempfiles=data/osmupdate_temp/temp --drop-version --hash-memory=$HASHMEM data/updated.o5m; then
    echo "Update error"
    exit
fi

mv data/updated.o5m data/local.o5m
osmfilter data/local.o5m --parameter-file=config/osm.filter -o=data/filtered.o5m --hash-memory=$HASHMEM
osmconvert data/filtered.o5m --timestamp=`osmconvert data/local.o5m --out-timestamp` -B=config/poly/$REGION.poly --complex-ways -o=data/filtered.pbf --hash-memory=$HASHMEM
rm data/filtered.o5m

#Import to DB
if ! bin/imposm3 import -diff=true -config=config/imposm.json -read data/filtered.pbf -write -overwritecache=true; then
    echo "Imposm error"
    exit
fi
exit

psql -Upostgres -dosm -v scm=import < sql/admin.sql
psql -Upostgres -dosm -v scm=import < sql/places.sql
psql -Upostgres -dosm -v scm=import < sql/streets.old.sql
psql -Upostgres -dosm -v scm=import < sql/buildings.sql
psql -Upostgres -dosm -v scm=import < sql/names.sql
psql -Upostgres -dosm -v scm=import < sql/poi.sql
#psql -Upostgres -dosm -v scm=import < sql/update.sql

psql -Upostgres -dosm < sql/views2public.sql
psql -Upostgres -dosm < sql/import2public.sql
psql -Upostgres -dosm < sql/layers.sql