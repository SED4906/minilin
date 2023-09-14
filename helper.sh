#!/bin/sh

touch_dir () {
    if [ ! -d "$1" ]; then
    mkdir "$1"
    fi
}

truncate_dir () {
    if [ -d "$1" ]; then
    rm -rf "$1"
    fi
    mkdir "$1"
}

mkdir_under () {
    pushd "$1"
    shift
    mkdir "$@"
    popd
}