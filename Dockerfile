# syntax=docker/dockerfile:1.4

ARG ZEPPELIN_VERSION
ARG SPARK_PSEUDO_BASE_IMAGE

# Zeppelin 0.10.1 Python interpreter does not work with Python > 3.9 as per
# https://stackoverflow.com/questions/59636631/importerror-cannot-import-name-mutablemapping-from-collections
# Base images must use Python 3.8
FROM $SPARK_PSEUDO_BASE_IMAGE AS builder

USER root

RUN apt-get update && apt-get install -y --no-install-recommends\
 wget\
 ca-certificates &&\
 apt-get autoremove -yqq --purge &&\
 rm -rf /var/lib/apt/lists/* &&\
 rm -rf /var/log/*

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

WORKDIR /tmp
ARG ZEPPELIN_VERSION
# Use this to get the closest mirror:
# curl 'https://www.apache.org/dyn/closer.cgi' | grep -o '<strong>[^<]*</strong>' | sed 's/<[^>]*>//g' | head -1
RUN wget -qO-\
 https://dlcdn.apache.org/zeppelin/zeppelin-$ZEPPELIN_VERSION/zeppelin-$ZEPPELIN_VERSION-bin-netinst.tgz |\
 tar -xzf -
# COPY files/zeppelin-0.10.1-bin-netinst.tgz .
# RUN tar -xzf zeppelin-0.10.1-bin-netinst.tgz

# Use our own interpreter.json file.
COPY files/interpreter.json zeppelin-$ZEPPELIN_VERSION-bin-netinst/conf/interpreter.json

# Merge the Cassandra Interpreter definition into conf/interpreter.json
COPY scripts/interpreter-*.py zeppelin-$ZEPPELIN_VERSION-bin-netinst/

COPY files/interpreter-cassandra.json.j2 zeppelin-$ZEPPELIN_VERSION-bin-netinst/conf

WORKDIR /tmp/zeppelin-$ZEPPELIN_VERSION-bin-netinst/local-repo/cassandra
ARG MAVEN_REPO=https://repo1.maven.org/maven2
RUN wget $MAVEN_REPO/org/scala-lang/scala-reflect/2.12.15/scala-reflect-2.12.15.jar &&\
 wget $MAVEN_REPO/org/scalatra/scalate/scalate-core_2.12/1.9.8/scalate-core_2.12-1.9.8.jar &&\
 wget $MAVEN_REPO/org/scalatra/scalate/scalate-util_2.12/1.9.8/scalate-util_2.12-1.9.8.jar &&\
 wget $MAVEN_REPO/org/scala-lang/scala-library/2.12.15/scala-library-2.12.15.jar &&\
 wget $MAVEN_REPO/org/scala-lang/modules/scala-parser-combinators_2.12/2.1.1/scala-parser-combinators_2.12-2.1.1.jar &&\
 wget $MAVEN_REPO/org/scala-lang/scala-compiler/2.12.15/scala-compiler-2.12.15.jar &&\
 wget $MAVEN_REPO/org/scala-lang/modules/scala-xml_2.12/2.1.0/scala-xml_2.12-2.1.0.jar


### builder layer end

ARG SPARK_PSEUDO_BASE_IMAGE

FROM $SPARK_PSEUDO_BASE_IMAGE AS main

USER root

# Run everything as ZEPPELIN_USER
ARG ZEPPELIN_USER=hdfs
ARG ZEPPELIN_GROUP=hdfs
ARG ZEPPELIN_HOME=/home/hdfs

COPY scripts/zeppelin-bootstrap.sh /zeppelin-bootstrap.sh

WORKDIR $ZEPPELIN_HOME
ARG ZEPPELIN_VERSION
COPY --from=builder --chown=$ZEPPELIN_USER:$ZEPPELIN_GROUP\
 /tmp/zeppelin-$ZEPPELIN_VERSION-bin-netinst/ zeppelin-$ZEPPELIN_VERSION-bin-netinst
RUN ln -s zeppelin-$ZEPPELIN_VERSION-bin-netinst zeppelin

# Remove unwanted interpreters.
WORKDIR $ZEPPELIN_HOME/zeppelin/interpreter/
RUN rm -fr angular\
 flink\
 influxdb\
 kotlin\
 r

WORKDIR $ZEPPELIN_HOME/.local
RUN chown -R $ZEPPELIN_USER:$ZEPPELIN_GROUP .

# YARN ResourceManager port.
EXPOSE 8032

# YARN ResourceManager webapp port.
EXPOSE 8088

# YARN NodeManager webapp port.
EXPOSE 8042

# Spark HistoryServer web UI port.
EXPOSE 18080

WORKDIR $ZEPPELIN_HOME
USER $ZEPPELIN_USER

# Create the zeppelin-env.sh file.
RUN echo 'export USE_HADOOP=true\n\
export SPARK_HOME=/opt/spark/\n\
export HADOOP_CONF_DIR=/opt/hadoop/etc/hadoop/\n'\
>> zeppelin/conf/zeppelin-env.sh

# Ditch the crappy, default tutes ...
RUN rm -fr zeppelin/notebook/*
ARG NOTEBOOK_SRC="files/notebook/Zeppelin Tutes"
ARG NOTEBOOK_DEST="zeppelin/notebook/Zeppelin Tutes"
ADD --chown=$ZEPPELIN_USER:$ZEPPELIN_GROUP $NOTEBOOK_SRC $NOTEBOOK_DEST

# Need iPython for python interpreter.
#
# Check https://setuptools.pypa.io/en/latest/history.html#v58-0-0 as
# to why we're pinning setuptools<58
RUN python -m pip install --user --upgrade pip "setuptools<58"

RUN python -m pip install --user\
 --no-compile\
 --no-cache-dir\
 protobuf==3.20.*

RUN python -m pip install --user\
 --no-compile\
 --no-cache-dir\
 altair\
 bokeh\
 bundle\
 grpcio\
 hvplot\
 intake-parquet\
 intake-xarray\
 intake\
 ipykernel\
 ipython\
 "jupyter-client<7.0.0"\
 matplotlib\
 msgpack\
 pandas\
 plotnine\
 protobuf\
 s3fs\
 seaborn\
 tzdata\
 vega_datasets &&\
 find .local/lib/python*/site-packages/ -depth\
   \(\
     \( -type d -a \( -name test -o -name tests -o -name idle_test \) \) \
     -o \
     \( -type f -a \( -name '*.pyc' -o -name '*.pyo' \) \) \
  \) -exec rm -rf '{}' +;

RUN ZEPPELIN_HOME=$ZEPPELIN_HOME/zeppelin\
 zeppelin/bin/install-interpreter.sh\
 --name cassandra\
 --artifact org.apache.zeppelin:zeppelin-cassandra:$ZEPPELIN_VERSION

ENTRYPOINT [ "/zeppelin-bootstrap.sh" ]
CMD []
