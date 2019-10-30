you need docker & docker-compose to make that test.

just clone the repo and run ./test.sh

With first run it will build clickhouse image, so can take more time.

By default it builds clickhouse image from PR build - also installs some debug tools & symbols package.
Please check & adjust ci_build/Dockerfile if needed.

It runs zookeeper (needed for Kafka), kafka & clickhouse containers,
put some test data into kafka topic, and create consuming pipeline
in clickhouse.

After that it just open a bash shell - so you can play with different
queries / run `perf top` inside container, etc.

Just run `docker-compose down` after plaing with that.