#!/bin/sh
# Runs once, the first time the PostgreSQL volume is created.
# Creates the database that `php artisan test` uses, so the feature tests never
# touch development data - and never fall back to SQLite.
set -e

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    CREATE DATABASE waffir_test OWNER $POSTGRES_USER ENCODING 'UTF8';
EOSQL
