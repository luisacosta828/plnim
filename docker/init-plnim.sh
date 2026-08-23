#!/bin/bash
echo "init-plnim.sh"
set -e

until pg_isready -U postgres; do
    sleep 1
done

#echo -n "NIMPATH = '$PG_HOME/.nimble'" >> /etc/postgresql/15/main/environment
psql -U postgres -d postgres -f /var/lib/postgresql/plnim/src/plnim/sql/extension.sql

