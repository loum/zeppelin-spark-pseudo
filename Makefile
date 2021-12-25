.DEFAULT_GOAL := help

MAKESTER__REPO_NAME := loum

ZEPPELIN_VERSION := 0.10.0
SPARK_VERSION := 3.2.0

# Tagging convention used: <zeppelin-version>-<spark-version>-<image-release-number>
MAKESTER__VERSION := $(ZEPPELIN_VERSION)-$(SPARK_VERSION)
MAKESTER__RELEASE_NUMBER := 1

MAKESTER__CONTAINER_NAME := zeppelin-spark-pseudo

include makester/makefiles/makester.mk
include makester/makefiles/docker.mk
include makester/makefiles/python-venv.mk

UBUNTU_BASE_IMAGE := focal-20211006
SPARK_PSEUDO_BASE_IMAGE := 3.3.1-$(SPARK_VERSION)

MAKESTER__BUILD_COMMAND = $(DOCKER) build --rm\
 --no-cache\
 --build-arg UBUNTU_BASE_IMAGE=$(UBUNTU_BASE_IMAGE)\
 --build-arg SPARK_PSEUDO_BASE_IMAGE=$(SPARK_PSEUDO_BASE_IMAGE)\
 --build-arg ZEPPELIN_VERSION=$(ZEPPELIN_VERSION)\
 -t $(MAKESTER__IMAGE_TAG_ALIAS) .

ZEPPELIN_ADDR ?= 0.0.0.0
ZEPPELIN_PORT ?= 18888
ZEPPELIN_INTERPRETER_DEP_MVNREPO ?= https://repo1.maven.org/maven2/
MAKESTER__RUN_COMMAND := $(DOCKER) run --rm -d\
 --name $(MAKESTER__CONTAINER_NAME)\
 --hostname $(MAKESTER__CONTAINER_NAME)\
 --env ZEPPELIN_ADDR=$(ZEPPELIN_ADDR)\
 --env ZEPPELIN_PORT=$(ZEPPELIN_PORT)\
 --env ZEPPELIN_INTERPRETER_DEP_MVNREPO=$(ZEPPELIN_INTERPRETER_DEP_MVNREPO)\
 --env SPARK_HOME=/opt/spark\
 --env YARN_SITE__YARN_NODEMANAGER_RESOURCE_DETECT_HARDWARE_CAPABILITIES:=true\
 --publish 7077:7077\
 --publish 8032:8032\
 --publish 8088:8088\
 --publish 8042:8042\
 --publish 18080:18080\
 --publish $(ZEPPELIN_PORT):$(ZEPPELIN_PORT)\
 $(MAKESTER__SERVICE_NAME):$(HASH)

init: clear-env makester-requirements

backoff:
	@$(PYTHON) makester/scripts/backoff -d "YARN ResourceManager" -p 8032 localhost
	@$(PYTHON) makester/scripts/backoff -d "YARN ResourceManager webapp UI" -p 8088 localhost
	@$(PYTHON) makester/scripts/backoff -d "YARN NodeManager webapp UI" -p 8042 localhost
	@$(PYTHON) makester/scripts/backoff -d "Spark HistoryServer web UI port" -p 18080 localhost
	@$(PYTHON) makester/scripts/backoff -d "Web UI for Zeppelin" -p $(ZEPPELIN_PORT) localhost

controlled-run: run backoff
	@$(shell which xdg-open) http://localhost:$(ZEPPELIN_PORT)

hadoop-version:
	@$(DOCKER) exec -ti $(MAKESTER__CONTAINER_NAME) /opt/hadoop/bin/hadoop version || true

spark-version:
	@$(DOCKER) exec $(MAKESTER__CONTAINER_NAME) bash -c\
 "HADOOP_CONF_DIR=/opt/hadoop/etc/hadoop /opt/spark/bin/spark-submit --version" || true

pi:
	@$(DOCKER) exec $(MAKESTER__CONTAINER_NAME) bash -c\
 "HADOOP_CONF_DIR=/opt/hadoop/etc/hadoop /opt/spark/bin/spark-submit --class org.apache.spark.examples.SparkPi\
 --files /opt/spark/conf/metrics.properties.template\
 --master yarn\
 --deploy-mode cluster\
 --driver-memory 1g\
 --executor-memory 1g\
 --executor-cores 1\
 /opt/spark/examples/jars/spark-examples_2.*-$(SPARK_VERSION).jar"

yarn-apps:
	@$(DOCKER) exec -ti $(MAKESTER__CONTAINER_NAME)\
 bash -c "/opt/hadoop/bin/yarn application -list -appStates ALL"

check-yarn-app-id:
	$(call check_defined, YARN_APPLICATION_ID)
yarn-app-log: check-yarn-app-id
	@$(DOCKER) exec -ti $(MAKESTER__CONTAINER_NAME)\
 bash -c "/opt/hadoop/bin/yarn logs -log_files stdout -applicationId $(YARN_APPLICATION_ID)"

pyspark: backoff
	@$(DOCKER) exec -ti $(MAKESTER__CONTAINER_NAME)\
 bash -c "/opt/spark/bin/pyspark"

spark: backoff
	@$(DOCKER) exec -ti $(MAKESTER__CONTAINER_NAME)\
 bash -c "/opt/spark/bin/spark-shell"

help: makester-help docker-help python-venv-help
	@echo "(Makefile)\n\
  controlled-run       Start and wait until all container services stabilise\n\
  hadoop-version       Hadoop version in running container $(MAKESTER__CONTAINER_NAME)\"\n\
  spark-version        Spark version in running container $(MAKESTER__CONTAINER_NAME)\"\n\
  yarn-apps            List all YARN application IDs\n\
  yarn-app-log         Dump log for YARN application ID defined by \"YARN_APPLICATION_ID\"\n\
  pyspark              Start the pyspark REPL\n\
  spark                Start the spark REPL\n\
  pi                   Run the sample Spark Pi application\n"
