#!/bin/bash

# Remove the users that have started the registrations, but never finished it (no verify_time) and have not subscription either.

export sqlite=/usr/bin/sqlite3

if [ ! -e $sqlite ]; then
    echo "$sqlite not found."
    echo "exiting..."
    exit
fi

export db=$1

if [ "$1" == "" ]; then
    echo "Please supply the name of the databaes (e.g. pm.db or cm.db) e.g.:"
    echo "$0 pm.db"
    echo "$0 cm.db"
    exit
fi

if [ ! -e $db ];then
    echo "Database file $db does not exist"
    exit
fi

export backup=${db}_$(date "+%Y%m%d-%H%M%S")
echo $backup

echo "Backup $db as $backup"
cp $db $backup

echo "Total number of users:"
echo "select count(*) from user;" | $sqlite $db

echo "Number of users to be deleted:"
echo "select count(*) from user where verify_time is NULL AND id NOT IN (SELECT uid FROM subscription);" | $sqlite $db

echo "Deleting..."
echo "delete from user where verify_time is NULL AND id NOT IN (SELECT uid FROM subscription);" | $sqlite $db

echo "Vacuuming..."
echo "VACUUM" | $sqlite $db

echo "Total number of users:"
echo "select count(*) from user;" | $sqlite $db

echo "Number of users remaining without verify_time::"
echo "select count(*) from user where verify_time is NULL AND id NOT IN (SELECT uid FROM subscription);" | $sqlite $db

