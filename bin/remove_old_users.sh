#!/bin/bash

# Remove the users that have started the registrations, but never finished it (no verify_time) and have not subscription either.

echo "select count(*) from user where verify_time is NULL AND id NOT IN (SELECT uid FROM subscription);" | sqlite pm.db
echo "delete from user where verify_time is NULL AND id NOT IN (SELECT uid FROM subscription);" | sqlite pm.db
echo "select count(*) from user where verify_time is NULL AND id NOT IN (SELECT uid FROM subscription);" | sqlite pm.db


