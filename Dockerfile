ARG ZEPPELIN_VERSION
ARG UBUNTU_BASE_IMAGE
ARG SPARK_PSEUDO_BASE_IMAGE

FROM ubuntu:$UBUNTU_BASE_IMAGE AS downloader

RUN apt-get update && apt-get install -y --no-install-recommends\
 wget\
 ca-certificates

SHELL ["/bin/bash", "-o", "pipefail", "-c"]
WORKDIR /tmp
ARG ZEPPELIN_VERSION
RUN wget -qO-\
 https://apache.mirror.digitalpacific.com.au/zeppelin/zeppelin-$ZEPPELIN_VERSION/zeppelin-$ZEPPELIN_VERSION-bin-netinst.tgz |\
 tar -C . -xzf -

# Use our own interpreter.json file.
COPY files/interpreter.json zeppelin-${ZEPPELIN_VERSION}-bin-netinst/conf/interpreter.json

# Merge the Cassandra Interpreter definition into conf/interpreter.json
COPY scripts/interpreter-*.py zeppelin-${ZEPPELIN_VERSION}-bin-netinst/

COPY files/interpreter-cassandra.json.j2 zeppelin-${ZEPPELIN_VERSION}-bin-netinst/conf

WORKDIR /tmp/zeppelin-$ZEPPELIN_VERSION-bin-netinst/local-repo/cassandra
ARG MAVEN_REPO=https://repo1.maven.org/maven2
RUN wget $MAVEN_REPO/org/scala-lang/scala-reflect/2.11.7/scala-reflect-2.11.7.jar &&\
 wget $MAVEN_REPO/org/scalatra/scalate/scalate-core_2.11/1.7.1/scalate-core_2.11-1.7.1.jar &&\
 wget $MAVEN_REPO/org/scalatra/scalate/scalate-util_2.11/1.7.1/scalate-util_2.11-1.7.1.jar &&\
 wget $MAVEN_REPO/org/scala-lang/scala-library/2.11.7/scala-library-2.11.7.jar &&\
 wget $MAVEN_REPO/org/scala-lang/modules/scala-parser-combinators_2.11/1.0.4/scala-parser-combinators_2.11-1.0.4.jar &&\
 wget $MAVEN_REPO/org/scala-lang/scala-compiler/2.11.7/scala-compiler-2.11.7.jar &&\
 wget $MAVEN_REPO/org/scala-lang/modules/scala-xml_2.11/1.0.4/scala-xml_2.11-1.0.4.jar

### downloader layer end

ARG SPARK_PSEUDO_BASE_IMAGE
FROM loum/spark-pseudo:$SPARK_PSEUDO_BASE_IMAGE

USER root
ARG PYTHON3_PIP
RUN apt-get update && apt-get install -y --no-install-recommends\
 python3-pip=$PYTHON3_PIP\
 python3-venv\
 build-essential\
 python3-dev &&\
 rm -rf /var/lib/apt/lists/*

# Run everything as ZEPPELIN_USER
ARG ZEPPELIN_USER=hdfs
ARG ZEPPELIN_GROUP=hdfs
ARG ZEPPELIN_HOME=/home/hdfs

COPY scripts/zeppelin-bootstrap.sh /zeppelin-bootstrap.sh

WORKDIR $ZEPPELIN_HOME
ARG ZEPPELIN_VERSION
COPY --from=downloader --chown=$ZEPPELIN_USER:$ZEPPELIN_GROUP\
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

# Need iPython for python interpreter.
RUN python -m venv 3env
RUN 3env/bin/python -m pip install --upgrade pip setuptools
RUN 3env/bin/python -m pip install\
 --no-cache-dir\
 jupyter-client\
 grpcio\
 protobuf\
 ipykernel\
 ipython\
 matplotlib\
 plotnine\
 seaborn\
 bokeh\
 bundle\
 hvplot\
 intake\
 intake-parquet\
 intake-xarray\
 msgpack\
 altair\
 vega_datasets

RUN ZEPPELIN_HOME=$ZEPPELIN_HOME/zeppelin\
 zeppelin/bin/install-interpreter.sh\
 --name cassandra\
 --artifact org.apache.zeppelin:zeppelin-cassandra:0.10.0

ENTRYPOINT [ "/zeppelin-bootstrap.sh" ]
