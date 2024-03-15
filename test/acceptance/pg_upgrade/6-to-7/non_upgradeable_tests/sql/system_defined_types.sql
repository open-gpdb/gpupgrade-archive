-- Copyright (c) 2017-2023 VMware, Inc. or its affiliates
-- SPDX-License-Identifier: Apache-2.0

-- System defined types are not guaranteed to have consistent oids when moving
-- from on version of postgres to the next. The query that looks for these
-- types had to be rewritten for upgrade because the recursive query looking
-- for these types of relations contained a self reference in a subquery. This
-- specific type of query is disabled in 6x so it was rewritten in plpgsql.

--------------------------------------------------------------------------------
-- Create and setup non-upgradeable objects
--------------------------------------------------------------------------------
CREATE TABLE table_using_system_defined_type (
	pg_type_column pg_type
);

-- build custom types that depend on each other to test recursive query used to
-- find the tables that depend on system-defined types.
CREATE TYPE custom_type_using_system_defined AS (
	id int,
	t0 pg_type
);
CREATE TYPE arr_custom_type1 AS (
	id int,
	t1 custom_type_using_system_defined[]
);
CREATE TYPE arr_custom_type2 AS (
	id int,
	t2 arr_custom_type1[]
);
CREATE TYPE arr_custom_type3 AS (
	id int,
	t3 arr_custom_type2[]
);
CREATE TABLE table_using_multiple_layers_of_system_types (
    id int,
    ct0 custom_type_using_system_defined,
    ct1 arr_custom_type1,
    ct2 arr_custom_type2,
    ct3 arr_custom_type3
);

CREATE TYPE custom_range_type_using_system_defined AS RANGE (
    subtype = pg_type
);
CREATE TABLE table_using_system_defined_range (
    id int,
    custom_range custom_range_type_using_system_defined NOT NULL
);

CREATE DOMAIN custom_domain_type_using_system_defined AS custom_range_type_using_system_defined;
CREATE TABLE table_using_system_defined_domain (
    id int,
    custom_domain custom_domain_type_using_system_defined NOT NULL
);

---------------------------------------------------------------------------------
--- Assert that pg_upgrade --check correctly detects the non-upgradeable objects
---------------------------------------------------------------------------------
!\retcode gpupgrade initialize --source-gphome="${GPHOME_SOURCE}" --target-gphome=${GPHOME_TARGET} --source-master-port=${PGPORT} --disk-free-ratio 0 --non-interactive;
! find $(ls -dt ~/gpAdminLogs/gpupgrade/pg_upgrade_*/ | head -1) -name "tables_using_composite.txt" -exec cat {} +;

---------------------------------------------------------------------------------
--- Workaround to unblock upgrade
---------------------------------------------------------------------------------
DROP TABLE table_using_system_defined_domain;
DROP TABLE table_using_system_defined_range;
DROP TABLE table_using_multiple_layers_of_system_types;
DROP TABLE table_using_system_defined_type;

DROP TYPE custom_domain_type_using_system_defined;
DROP TYPE custom_range_type_using_system_defined;
DROP TYPE arr_custom_type3;
DROP TYPE arr_custom_type2;
DROP TYPE arr_custom_type1;
DROP TYPE custom_type_using_system_defined;
