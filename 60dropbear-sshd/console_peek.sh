#!/bin/sh
N=${1:-1}
exec setterm -dump "$N" -file /proc/self/fd/1
