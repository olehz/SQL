#!/bin/bash
rm data/cache/*.gz
timestamp=`sed -n 1p data/cache/last.state.txt`
timestamp=${timestamp:10}
timestamp=`echo $timestamp | sed 's/\\\:/:/g'`
timestamp=`date -u --date="$timestamp" "+%Y-%m-%dT%H:%M:%SZ"`
echo $timestamp
if ! osmupdate $timestamp --keep-tempfiles --tempfiles=data/tmp/0 data/cache/local.osc.gz; then
	echo "Osmupdate error"
	notify-send Imposm3 Error
    exit
fi

last=`ls -1t data/tmp/*.txt|head -n 1`
mv $last data/cache/local.state.txt
rm data/tmp/*

if ! bin/imposm3 diff -diffdir=data/cache -config=config/imposm.json data/cache/local.osc.gz; then
    echo "Imposm error"
    notify-send "Imposm error"
    exit
fi