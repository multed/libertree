#!/bin/bash
set -o nounset # abort if we try to use an unset variable
set -o errexit # exit if any statement returns a non-true return value

CONFIG_FILE=${1:-database.yaml}
SCRIPT_DIR="$( cd -P "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

export PGOPTIONS="--client-min-messages=warning${PGOPTIONS:+:$PGOPTIONS}"

function parse_config
{
  # - ignore commented lines
  # - get lines that belong to the specified section
  # - define variables

  local SECTION=${LIBERTREE_ENV:=development}
  local SAVEIFS=$IFS
  local SECTION_EXISTS="false"
  IFS=$'\n'

  for line in $(sed -ne '/^\s*#/d' -e "/^$SECTION/,/^[a-z]/{/^[a-z]/!p}" $CONFIG_FILE); do
    SECTION_EXISTS="true"
    IFS=" " read key value <<< $(echo $line | sed -e 's/[^a-z ]//')
    eval "libertree_db_$key=$value"
  done
  IFS=$SAVEIFS

  # bogus environment?
  if [ $SECTION_EXISTS = "false" ]; then
    echo "ERROR: the environment \"$SECTION\" is undefined"
    exit 1
  else
    echo "Loaded $SECTION environment"
  fi

  # ensure that all required connection variables are defined
  [ -n ${libertree_db_username:?"Database username undefined."} ]
  [ -n ${libertree_db_database:?"Database name undefined."} ]

  # TODO: use password if it is defined
  export psql_options="-X --quiet -v ON_ERROR_STOP=1 -v VERBOSITY=terse --username $libertree_db_username --dbname $libertree_db_database"

  # pass host option only if libertree_db_host exists
  if [ ! -z "${libertree_db_host:-}" ]; then
      export psql_options="$psql_options --host $libertree_db_host"
  fi

  return 0
}

function ensure_migration_table_exists
{
  execute "SELECT 'exists' FROM pg_tables WHERE schemaname='public' AND tablename = 'schema_migrations'" | grep -q "exists" || \
    execute "CREATE TABLE schema_migrations ( filename VARCHAR(1024) NOT NULL UNIQUE )"
}

function apply_migrations
{
  migrations=$( migrations_to_apply )
  if [ -z "$migrations" ]; then
    echo "No migrations to apply."
  else
    for migration in $migrations; do
      echo "Applying: $migration"
      ( psql $psql_options --single-transaction --file ${SCRIPT_DIR}/migrations/$migration \
        && execute "INSERT INTO schema_migrations ( filename ) VALUES ('$migration')") || \
        { echo "ERROR: failed to apply migration \"$migration\"."; exit 1; }
    done
    echo -e "\nDone."
  fi
}

function load_functions
{
  # drop all existing triggers, because they might depend on functions
  # that are to be dropped
  while read pair; do
    local trigger=$( echo "$pair" | cut -d'|' -f1)
    local table=$( echo "$pair" | cut -d'|' -f2)
    echo "Dropping trigger $trigger ON table $table"
    execute "DROP TRIGGER IF EXISTS $trigger ON $table"
  done < <(execute "SELECT trigger_name, event_object_table FROM information_schema.triggers;")

  # drop all existing user functions
  while read func; do
    echo "Dropping function $func"
    execute "DROP FUNCTION IF EXISTS $func"
  done < <(execute "SELECT proname || '(' || oidvectortypes(proargtypes) || ')' \
                    FROM pg_proc INNER JOIN pg_namespace ns \
                    ON (pg_proc.pronamespace = ns.oid AND ns.nspname='public');")

  for file in ${SCRIPT_DIR}/functions/*.sql; do
    echo "Loading functions from: $file"
    psql $psql_options --single-transaction --file $file
  done
}

# return a sorted list of migrations that have not yet been applied
function migrations_to_apply
{
  execute "SELECT filename FROM schema_migrations" | sort | \
    diff --changed-group-format="%<" --unchanged-group-format='' \
    <( find ${SCRIPT_DIR}/migrations -name \*.sql -printf '%f\n' | sort) - |\
    sed -e 's/$/ /g'
}

function execute
{
  echo "$1" | psql $psql_options --tuples-only --no-align
}

# ---------------------------------------
parse_config
ensure_migration_table_exists
apply_migrations
load_functions
# ---------------------------------------
