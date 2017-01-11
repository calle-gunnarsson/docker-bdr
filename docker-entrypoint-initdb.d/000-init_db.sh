#!/bin/bash -x
MASTER_DSN=""
CONTAINER_IP=$(hostname -i | cut -d' ' -f1)
NODES=`PGPASSWORD=$POSTGRES_PASSWORD psql --host postgres_master --username $POSTGRES_USER $POSTGRES_DB -t -c "SELECT COUNT(*) FROM bdr.bdr_nodes" | xargs echo`

echo "REPLICATED:$NODES"

if [ $NODES -eq 0 ]; then
PGPASSWORD=$POSTGRES_PASSWORD psql --username $POSTGRES_USER $POSTGRES_DB <<-SQL
CREATE TABLE names (
	id    uuid PRIMARY KEY NOT NULL DEFAULT uuid_generate_v4(),
	name  varchar(40)
);
CREATE UNIQUE INDEX name ON names (name);

SELECT bdr.bdr_group_create(
	local_node_name := 'postgres_master',
	node_external_dsn := 'user=$POSTGRES_USER password=$POSTGRES_PASSWORD dbname=$POSTGRES_DB host=postgres_master'
);
SELECT bdr.bdr_node_join_wait_for_ready();
SQL

else
	PGPASSWORD=$POSTGRES_PASSWORD psql --username $POSTGRES_USER $POSTGRES_DB <<-SQL
	SELECT bdr.bdr_group_join(
		local_node_name := 'node_$HOSTNAME',
		node_external_dsn := 'user=$POSTGRES_USER password=$POSTGRES_PASSWORD dbname=$POSTGRES_DB host=$CONTAINER_IP',
		join_using_dsn := 'user=$POSTGRES_USER password=$POSTGRES_PASSWORD dbname=$POSTGRES_DB host=postgres_master'
	);
	SELECT bdr.bdr_node_join_wait_for_ready();
SQL

fi
