#!/bin/bash

PROGNAME=$(basename $0)
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
 
print_usage() {
  echo "Usage: $0 [launch|destroy]"
  echo ""
  echo "    launch  : Launch hadoop cluster on docker"
  echo "    destroy : Remove hadoop cluster on docker"
  echo "    build   : Build docker images with local hadoop binary"
  echo ""
  echo "    Options:"
  echo "        -h,  --help      : Print usage"
  echo "        -s, --slaves : Specify the number of slaves"
  echo ""
}

if [ $# -eq 0 ]; then
  print_usage
fi

DATANODE_NUM=3
CLUSTER_NAME=default_cluster

for OPT in "$@"
do
    case "$OPT" in
        '-h'|'--help' )
            print_usage
            exit 1
            ;;
        '-s'|'--slaves' )
            if [[ -z "$2" ]] || [[ "$2" =~ ^-+ ]]; then
                echo "$PROGNAME: option requires an argument -- $1" 1>&2
                exit 1
            fi
            DATANODE_NUM="$2"
            shift 2
            ;;
        '-c'|'--cluster' )
            CLUSTER_NAME="$2"
            shift 2
            ;;
        -*)
            echo "$PROGNAME: illegal option -- '$(echo $1 | sed 's/^-*//')'" 1>&2
            exit 1
            ;;
        *)
            ;;
    esac
done

launch_cluster() {
  if ! docker network inspect hadoop-network > /dev/null ; then
    docker network create --driver bridge hadoop-network
  fi
  docker run -d -p 50070:50070 -p 8088:8088 -v /home/mr/projects/java/hadoop/hdfsio/nn/input:/usr/local/hadoop/hdfsio/input --net hadoop-network --name nn -h nn lewuathe/hadoop-master
  for i in `seq 1 $DATANODE_NUM`; do
    docker run -d --name dn${i} -h dn${i} -v /home/mr/projects/java/hadoop/hdfsio/dn${i}/input:/usr/local/hadoop/input --net hadoop-network lewuathe/hadoop-slave
  done
}

destroy_cluster() {
  docker kill nn; docker rm nn
  for i in `seq 1 $DATANODE_NUM`; do
    docker kill dn${i}; docker rm dn${i}
  done
}

build_images() {
  cd $DIR/../hadoop-base
  docker build -f Dockerfile-local -t lewuathe/hadoop-base .
  cd $DIR/../hadoop-master
  docker build -t lewuathe/hadoop-master .
  cd $DIR/../hadoop-slave
  docker build -t lewuathe/hadoop-slave .
}

case $1 in
    launch) launch_cluster
        ;;
    destroy) destroy_cluster
        ;;
    build) build_images
        ;;
esac

exit 0

