#!/bin/sh

nohup sh -c /spark-bootstrap.sh &

# Generate the Zeppelin Interpreter definition files.
3env/bin/python zeppelin/interpreter-setter.py -t "zeppelin/conf/interpreter-cassandra.json.j2"

# Create JDBC-based interpreter for Hive.
3env/bin/python zeppelin/interpreter-merge.py -p "zeppelin/conf"

# Start the Zeppelin server.
PATH="$PATH:/opt/hadoop/bin" zeppelin/bin/zeppelin-daemon.sh start

# Block until we signal exit.
trap 'exit 0' TERM
while true; do sleep 0.5; done
