FROM reg.docker.lhdrr.com:8081/lvhuan/openresty:1.21.4.1rc1

MAINTAINER tom2nonames <tom2nonames@gmail.com>

ARG LH_TAOS_VER=1.0
ARG LH_TAOS_DIR="/usr/local/lvhuan/lua-resty-taos"

RUN mkdir -p ${LH_TAOS_DIR}

WORKDIR ${LH_TAOS_DIR}

COPY lib       ./lib
COPY test.lua  ./

RUN dnf install -y gcc gcc-c++ make cmake epel-release git  libarchive unixODBC-devel flex

RUN \
       cd /tmp \
    && git clone https://github.com/taosdata/TDengine.git \
    && cd TDengine \
    && git checkout ver-2.4.0.12 \
    && git submodule update --init --recursive \
    && mkdir debug \
    && cd debug \
    && cmake .. \
    && cmake --build . \
    && make install



CMD ["sh", "-c", "/tmp/TDengine/debug/build/bin/taosd -c /tmp/TDengine/debug/test/cfg"]

STOPSIGNAL SIGQUIT