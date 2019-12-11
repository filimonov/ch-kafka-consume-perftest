FROM yandex/clickhouse-server

ARG deb_location="https://clickhouse-builds.s3.yandex.net/8035/f6e059a378393fdb3219b701fa507eac0277a446/1575999027_deb/"
ARG version=19.19.1.1836

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
    && DEBIAN_FRONTEND=noninteractive apt-get install --yes --no-install-recommends gdb binutils linux-tools-common linux-tools-generic linux-tools-`uname -r` \
    && wget --no-check-certificate ${deb_location}/clickhouse-common-static-dbg_${version}_amd64.deb \
    && DEBIAN_FRONTEND=noninteractive dpkg -i *.deb \
    && rm -rf \
        *.deb \
        /var/lib/apt/lists/* \
        /var/cache/debconf \
        /tmp/* \
    && apt-get clean