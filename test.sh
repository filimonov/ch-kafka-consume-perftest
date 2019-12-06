#!/usr/bin/env bash
docker-compose down

echo "Start the test stand"
docker-compose up -d

echo "Create dummy data in topic"

#DATA_SIZE=100000
DATA_SIZE=33554432
docker-compose exec -T clickhouse clickhouse-client \
  --query="SELECT number as id, intDiv( number, 65536 ) as block_no, base64Encode( reinterpretAsString( rand64() ) ) as val1, rand(1)*rand(2) / rand(3) as val2, rand(4) as val3, rand(5) as val4, rand(6) as val5, toString( rand64(2) ) as val6 from numbers($DATA_SIZE) FORMAT TSV" | \
  pv -l -s $DATA_SIZE | \
  docker-compose exec -T kafkacat kafkacat -b kafka:9092 -t dummytopic -P -l

cat <<HEREDOC | docker-compose exec -T clickhouse clickhouse-client -n
CREATE TABLE dummy_queue_tsv (
 id UInt64,
 block_no UInt64,
 val1 String,
 val2 Float64,
 val3 UInt32,
 val4 UInt32,
 val5 UInt32,
 val6 String
) ENGINE = Kafka()
SETTINGS
 kafka_broker_list = 'kafka:9092',
 kafka_topic_list = 'dummytopic',
 kafka_group_name = 'dummytopic_consumer_group2',
 kafka_format = 'TSV',
 kafka_row_delimiter = '\n';

CREATE TABLE kafka_stats (
    block_no UInt64,
    min_id SimpleAggregateFunction(min, UInt64),
    max_id SimpleAggregateFunction(max, UInt64),
    min_timestamp SimpleAggregateFunction(min, DateTime),
    max_timestamp SimpleAggregateFunction(max, DateTime),
    cnt           SimpleAggregateFunction(sum, UInt64),
    someval1      SimpleAggregateFunction(anyLast, String),
    someval2      SimpleAggregateFunction(anyLast, Float64),
    someval3      SimpleAggregateFunction(anyLast, UInt32),
    someval4      SimpleAggregateFunction(anyLast, UInt32),
    someval5      SimpleAggregateFunction(anyLast, UInt32),
    someval6      SimpleAggregateFunction(anyLast, String),
    timestamp     DateTime MATERIALIZED now()
) ENGINE = AggregatingMergeTree()
ORDER BY (block_no,timestamp);

CREATE MATERIALIZED VIEW dummy_queue_tsv_mv TO kafka_stats
AS SELECT
   block_no,
   min(id) as min_id,
   max(id) as max_id,
   min(_timestamp) as min_timestamp,
   max(_timestamp) as max_timestamp,
   sum( 1 ) as cnt,
   anyLast(val1) as someval1,
   anyLast(val2) as someval2,
   anyLast(val3) as someval3,
   anyLast(val4) as someval4,
   anyLast(val5) as someval5,
   anyLast(val6) as someval6
FROM dummy_queue_tsv
GROUP BY block_no;
HEREDOC

echo 'Consuming started'
echo '**********************************'
echo 'Opening bash inside clickhouse container'
echo '**********************************'
echo 'try that query in clickhouse-client: select version(), sum(cnt) record_count, max(max_timestamp) - min(min_timestamp) produce_time, record_count / produce_time produce_speed, max(timestamp) - min(timestamp) consume_time, record_count / consume_time as consume_speed from kafka_stats;'
echo 'perf top should also work in that container'
echo '**********************************'
docker-compose exec clickhouse bash

#clickhouse-client

# ┌─version()────┬─record_count─┬─produce_time─┬─────produce_speed─┬─consume_time─┬──────consume_speed─┐
# │ 19.14.7.15   │     33554432 │           50 │         671088.64 │          203 │  165292.7684729064 │
# │ 19.15.3.6    │     33554432 │           42 │ 798915.0476190476 │          623 │   53859.4414125200 │
# │ 19.17.1.1557 │     33554432 │           39 │ 860370.0512820513 │          499 │   67243.3507014028 │
# │ 19.18.1.1745 │     33554432 │           34 │ 986895.0588235294 │          276 │  121574.0298550725 │
# │ 19.18.1.1747 │     33554432 │           36 │ 932067.5555555555 │          241 │  139230.0082987552 │
# │ 19.18.1.1750 │     33554432 │           35 │ 958698.0571428571 │          204 │ 164482.50980392157 │
# └──────────────┴──────────────┴──────────────┴───────────────────┴──────────────┴────────────────────┘
