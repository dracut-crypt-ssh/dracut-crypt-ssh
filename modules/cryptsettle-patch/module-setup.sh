#!/bin/bash

check() {
	return 0
}

install() {
	for file in ${initdir}/cmdline/*parse-crypt.sh; do
		dinfo "Patching ${file}"
		sed -i -e "s!/sbin/initqueue!/sbin/initqueue --settled!g" ${file}
	done

	return 0
}

