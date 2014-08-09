#!/bin/bash

for file in ${initdir}/cmdline/*parse-crypt.sh; do
	dinfo "Patching ${file}"
	sed -i -e "s!/sbin/initqueue!/sbin/initqueue --settled!g" ${file}
done

