#!/bin/bash
cd $(dirname $0)

source scripts/func_podsys.sh
delete_logs
check_iplist_format "workspace/iplist.txt"

if docker ps -a --format '{{.Image}}' | grep -q "ainexus-lite:v3.0"; then
    docker stop $(docker ps -a -q --filter ancestor=ainexus-lite:v3.0) >/dev/null
    docker rm $(docker ps -a -q --filter ancestor=ainexus-lite:v3.0) >/dev/null
    docker rmi ainexus-lite:v3.0 >/dev/null
fi

docker import pkgs/ainexus-lite ainexus-lite:v3.0 >/dev/null &
pid=$!
while ps -p $pid >/dev/null; do
    echo -n "*"
    sleep 2
done
echo

docker run --name podsys --privileged=true -it --network=host -v $PWD/workspace:/workspace ainexus-lite:v3.0 /bin/bash

sleep 1
if docker ps -a --format '{{.Image}}' | grep -q "ainexus-lite:v3.0"; then
    docker stop $(docker ps -a -q --filter ancestor=ainexus-lite:v3.0) >/dev/null
    docker rm $(docker ps -a -q --filter ancestor=ainexus-lite:v3.0) >/dev/null
    docker rmi ainexus-lite:v3.0 >/dev/null
fi