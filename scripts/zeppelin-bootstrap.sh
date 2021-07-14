#!/bin/sh

nohup sh -c /spark-bootstrap.sh &

# Start the Zeppelin server.
PATH="$PATH:/opt/hadoop/bin" zeppelin/bin/zeppelin-daemon.sh start

# Block until we signal exit.
trap 'exit 0' TERM
while true; do sleep 0.5; done
