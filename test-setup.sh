#!/usr/bin/env bash
tmpdir=$(mktemp -d)
socketdir=${1:-$tmpdir}
echo "Using database temp dir $tmpdir"
export LC_ALL='en_US.UTF-8'
pg_ctl -D $tmpdir init
pg_ctl start -D $tmpdir -o "-k $socketdir -h ''"
createdb -h $socketdir test_rdc_website
echo "Loading test database..."
psql -h $socketdir test_rdc_website -f tests/test_db.sql
echo "export rdc_website_TEST_DB_URL=\"postgresql+psycopg2:///test_rdc_website?host=$socketdir\""