FROM yandex/clickhouse-server

ARG deb_location="https://clickhouse-builds.s3.yandex.net/7475/02003176eedd67527e1239e4ab89680db164ef17/1571927825_deb/"
ARG version=19.17.1.1557

RUN wget --no-check-certificate ${deb_location}/clickhouse-common-static_${version}_amd64.deb \
    && wget --no-check-certificate ${deb_location}/clickhouse-client_${version}_all.deb \
    && wget --no-check-certificate ${deb_location}/clickhouse-server_${version}_all.deb \
    && DEBIAN_FRONTEND=noninteractive dpkg -i *.deb \
    && rm -rf \
        *.deb \
        /var/lib/apt/lists/* \
        /var/cache/debconf \
        /tmp/* \
    && apt-get clean

# debug tools + symbols (optional)
RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install --yes --no-install-recommends binutils linux-tools-common linux-tools-generic linux-tools-`uname -r` \
    && wget --no-check-certificate ${deb_location}/clickhouse-common-static-dbg_${version}_amd64.deb \
    && DEBIAN_FRONTEND=noninteractive dpkg -i *.deb \
    && rm -rf \
        *.deb \
        /var/lib/apt/lists/* \
        /var/cache/debconf \
        /tmp/* \
    && apt-get clean