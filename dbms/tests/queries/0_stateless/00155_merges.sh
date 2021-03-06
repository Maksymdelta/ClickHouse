#!/bin/bash

function create {
	clickhouse-client --query="DROP TABLE IF EXISTS test.summing"
	clickhouse-client --query="DROP TABLE IF EXISTS test.collapsing"
	clickhouse-client --query="DROP TABLE IF EXISTS test.aggregating"
	
	clickhouse-client --query="CREATE TABLE test.summing (d Date DEFAULT today(), x UInt64, s UInt64 DEFAULT 1) ENGINE = SummingMergeTree(d, x, 8192)"
	clickhouse-client --query="CREATE TABLE test.collapsing (d Date DEFAULT today(), x UInt64, s Int8 DEFAULT 1) ENGINE = CollapsingMergeTree(d, x, 8192, s)"
	clickhouse-client --query="CREATE TABLE test.aggregating (d Date DEFAULT today(), x UInt64, s AggregateFunction(sum, UInt64)) ENGINE = AggregatingMergeTree(d, x, 8192)"
}


function cleanup {
	clickhouse-client --query="DROP TABLE test.summing"
	clickhouse-client --query="DROP TABLE test.collapsing"
	clickhouse-client --query="DROP TABLE test.aggregating"
}


function test {
	create
	
	SUM=$(( $1 + $2 ))
	MAX=$(( $1 > $2 ? $1 : $2 ))

	clickhouse-client --query="INSERT INTO test.summing (x) SELECT number AS x FROM system.numbers LIMIT $1"
	clickhouse-client --query="INSERT INTO test.summing (x) SELECT number AS x FROM system.numbers LIMIT $2"

	clickhouse-client --query="INSERT INTO test.collapsing (x) SELECT number AS x FROM system.numbers LIMIT $1"
	clickhouse-client --query="INSERT INTO test.collapsing (x) SELECT number AS x FROM system.numbers LIMIT $2"

	clickhouse-client --query="INSERT INTO test.aggregating (d, x, s) SELECT today() AS d, number AS x, sumState(materialize(toUInt64(1))) AS s FROM (SELECT number FROM system.numbers LIMIT $1) GROUP BY number"
	clickhouse-client --query="INSERT INTO test.aggregating (d, x, s) SELECT today() AS d, number AS x, sumState(materialize(toUInt64(1))) AS s FROM (SELECT number FROM system.numbers LIMIT $2) GROUP BY number"

	clickhouse-client --query="SELECT count() = $SUM, sum(s) = $SUM FROM test.summing"
	clickhouse-client --query="OPTIMIZE TABLE test.summing"
	clickhouse-client --query="SELECT count() = $MAX, sum(s) = $SUM FROM test.summing"
	echo
	clickhouse-client --query="SELECT count() = $SUM, sum(s) = $SUM FROM test.collapsing"
	clickhouse-client --query="OPTIMIZE TABLE test.collapsing"
	clickhouse-client --query="SELECT count() = $MAX, sum(s) = $MAX FROM test.collapsing"
	echo
	clickhouse-client --query="SELECT count() = $SUM, sumMerge(s) = $SUM FROM test.aggregating"
	clickhouse-client --query="OPTIMIZE TABLE test.aggregating"
	clickhouse-client --query="SELECT count() = $MAX, sumMerge(s) = $SUM FROM test.aggregating"
	echo
	echo
}

test 8191 8191
test 8191 8192
test 8192 8191
test 8192 8192
test 8192 8193
test 8193 8192
test 8193 8193
test 8191 8193
test 8193 8191
test 8193 8194
test 8194 8193
test 8194 8194

cleanup
