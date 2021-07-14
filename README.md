
# Apache Zeppelin (with Apache Spark on YARN over Pseudo Distributed Hadoop)
- [Overview](#Overview)
- [Quick Links](#Quick-Links)
- [Quick Start](#Quick-Start)
- [Prerequisites](#Prerequisites)
- [Getting Started](#Getting-Started)
- [Getting Help](#Getting-Help)
- [Docker Image Management](#Docker-Image-Management)
  - [Image Build](#Image-Build)
  - [Image Searches](#Image-Searches)
  - [Image Tagging](#Image-Tagging)
- [Interact with Zeppelin as Docker Container](#Interact-with-Zeppelin-as-Docker-Container)

## Overview
[Zeppelin](https://zeppelin.apache.org/docs/0.9.0/) on Docker with its own Apache Spark compute.

> **_NOTE:_** The `%python` interpreter has been disabled due to this [bug](https://issues.apache.org/jira/browse/ZEPPELIN-5032).  As per recommendation, `%ipython` is fully supported and is the preferred way to work with the Python 3 interpreter in Zeppelin.

## Quick Links
- [Apache Zeppelin](https://zeppelin.apache.org/)

## Quick Start
Impatient and just want Zeppelin with Spark quickly?
```
docker run --rm -d\
 --name zeppelin-spark-pseudo\
 --hostname zeppelin-spark-pseudo\
 --env ZEPPELIN_ADDR=0.0.0.0\
 --env ZEPPELIN_PORT=18888\
 --env ZEPPELIN_INTERPRETER_DEP_MVNREPO=https://repo1.maven.org/maven2/\
 --env SPARK_HOME=/opt/spark\
 --publish 7077:7077\
 --publish 8032:8032\
 --publish 8088:8088\
 --publish 8042:8042\
 --publish 18080:18080\
 --publish 18888:18888\
 loum/zeppelin-spark-pseudo:latest
```
## Prerequisites
- [Docker](https://docs.docker.com/install/)
- [GNU make](https://www.gnu.org/software/make/manual/make.html)

## Getting Started
Get the code and change into the top level `git` project directory:
```
git clone https://github.com/loum/zeppelin-spark-pseudo.git && cd zeppelin-spark-pseudo
```
> **_NOTE:_** Run all commands from the top-level directory of the `git` repository.

For first-time setup, get the [Makester project](https://github.com/loum/makester.git):
```
git submodule update --init
```
Keep [Makester project](https://github.com/loum/makester.git) up-to-date with:
```
make submodule-update
```
Setup the environment:
```
make init
```
## Getting Help
There should be a `make` target to get most things done.  Check the help for more information:
```
make help
```
## Docker Image Management
### Image Build
```
make build-image
```
### Image Searches
Search for existing Docker image tags with command:
```
make search-image
```
### Image Tagging
By default, `makester` will tag the new Docker image with the current branch hash.  This provides a degree of uniqueness but is not very intuitive.  That's where the `tag-version` `Makefile` target can help.  To apply tag as per project tagging convention `<zeppelin-version>-<spark-version>-<image-release-number>`:
```
make tag-version
```
To tag the image as `latest`
```
make tag-latest
```
## Interact with Zeppelin as Docker Container
To start the container and wait for the Zeppelin service to initiate:
```
make controlled-run
```
Browse to http://localhost:[ZEPPELIN_PORT] (`ZEPPELIN_PORT` defaults to `18888`).

To stop:
```
make stop
```

---
[top](#Apache-Zeppelin-(with-Apache-Spark-on-YARN-over-Pseudo-Distributed-Hadoop))
