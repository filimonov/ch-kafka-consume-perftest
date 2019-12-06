#!/usr/bin/env bash

#set -o xtrace

echo "Shutdown test stand (if was active)"
docker-compose down

echo "Start the test stand"
docker-compose up -d

# ClickHouse can't generate CapNProto & ORC output,
# so i use external converters (need to be built into docker image)

# capnproto (version from ubuntu repo is buggy)
# curl -O https://capnproto.org/capnproto-c++-0.7.0.tar.gz
# tar zxf capnproto-c++-0.7.0.tar.gz
# cd capnproto-c++-0.7.0
# ./configure
# make -j6 check
# sudo make install

# sudo snap install orc

FORMATS=(CSV CSVWithNames JSONEachRow Native RowBinary RowBinaryWithNamesAndTypes TSKV TSV TSVWithNames TSVWithNamesAndTypes Values CapnProto ORC Parquet Protobuf Template)
# Not checked (variants of above): TemplateIgnoreSpaces CustomSeparated CustomSeparatedIgnoreSpaces TabSeparated TabSeparatedWithNames TabSeparatedWithNamesAndTypes

for format in ${FORMATS[*]}
do
 echo "Generating data for $format"
 mkdir -p data-samples/$format
 extra_args=("--format=$format")
 if [ "$format" == "CapnProto" ]; then
    extra_args=('--format=Template')
    extra_args+=('--format_template_row="format_schemas/template_row.format"')
    extra_args+=(' | /usr/local/bin/capnp encode format_schemas/test.capnp TestRecordStruct')
 elif [ "$format" == "Template" ]; then
    extra_args+=('--format_template_row="format_schemas/template_row.format"')
 elif [ "$format" == "ORC" ]; then
    extra_args=('--format=JSONEachRow > _tmp_convert.json')
    extra_args+=('; rm -f *_tmp_convert.orc*')
    extra_args+=('; orc.java convert _tmp_convert.json -o _tmp_convert.orc')
    extra_args+=('; cat _tmp_convert.orc')
 elif [ "$format" == "Protobuf" ]; then_tmp_convert
    extra_args+=('--format_schema="format_schemas/test:TestMessage"')
 fi
 query="SELECT toInt64(number) as id, toUInt16( intDiv( id, 65536 ) ) as blockNo, reinterpretAsString(19777) as val1, toFloat32(0.5) as val2, toUInt8(1) as val3 from numbers(75000) ORDER BY id"
 bash -c "clickhouse-client --query='$query LIMIT 1' ${extra_args[*]} > data-samples/$format/1.dat"
 bash -c "clickhouse-client --query='$query LIMIT 1,15' ${extra_args[*]} > data-samples/$format/2.dat"
 bash -c "clickhouse-client --query='$query LIMIT 16,15000' ${extra_args[*]} > data-samples/$format/3.dat"
 bash -c "clickhouse-client --query='$query LIMIT 15016,15000' ${extra_args[*]} > data-samples/$format/4.dat"
 bash -c "clickhouse-client --query='$query LIMIT 30016,15000' ${extra_args[*]} > data-samples/$format/5.dat"
 bash -c "clickhouse-client --query='$query LIMIT 45016,15000' ${extra_args[*]} > data-samples/$format/6.dat"
 bash -c "clickhouse-client --query='$query LIMIT 60016,10000' ${extra_args[*]} > data-samples/$format/7.dat"
 bash -c "clickhouse-client --query='$query LIMIT 70016,100' ${extra_args[*]} > data-samples/$format/8.dat"

 if [ "$format" == "ORC" ]; then
    rm -f *_tmp_convert.*
    rm -f ._tmp_convert.*
 fi

done

for format in ${FORMATS[*]}
do
 echo "Producing $format"
 docker-compose exec -T kafkacat bash -c "kafkacat -b kafka:9092 -t dummytopic$format -P /data-samples/$format/*.dat"
done


for format in ${FORMATS[*]}
do
 echo "Setup ClickHouse pipeline for: $format"

 EXTRA=''
 if [ "$format" == "CapnProto" ]; then
    EXTRA=" , kafka_schema='test:TestRecordStruct'"
 elif [ "$format" == "Template" ]; then
    EXTRA=" , format_template_row='template_row.format'"
 elif [ "$format" == "Protobuf" ]; then
    EXTRA=" , kafka_schema='test:TestMessage'"
 fi

cat <<HEREDOC | docker-compose exec -T clickhouse clickhouse-client -n
DROP TABLE IF EXISTS queue$format;
CREATE TABLE queue$format (
 id Int64,
 blockNo UInt16,
 val1 String,
 val2 Float32,
 val3 UInt8
) ENGINE = Kafka()
SETTINGS
 kafka_broker_list = 'kafka:9092',
 kafka_topic_list = 'dummytopic$format',
 kafka_group_name = 'dummytopic$format_consumer_group',
 kafka_format = '$format',
 kafka_row_delimiter = '\n' $EXTRA;

DROP TABLE IF EXISTS queue_mv$format;
CREATE MATERIALIZED VIEW queue_mv$format Engine=MergeTree ORDER BY id AS SELECT *,  _key, _topic, _offset, _partition, _timestamp FROM queue$format;
HEREDOC

done

echo "waiting 10 secs to consume messages"

sleep 10

for format in ${FORMATS[*]}
do
 echo "Check the results for: $format"
 cat <<HEREDOC | docker-compose exec -T clickhouse clickhouse-client -n
SELECT * FROM queue_mv$format LIMIT 1;
SELECT count(), count() = 70116, uniqExact(id) = count() FROM queue_mv$format;
SELECT _offset, count() FROM queue_mv$format GROUP BY _offset ORDER BY _offset ASC;

HEREDOC
done
