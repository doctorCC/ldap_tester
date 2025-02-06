#!/bin/bash
sudo /usr/sbin/nscd
echo "Now exec the CMD from the Dockerfile eg. [$@]"
exec "$@"
