#!/bin/bash
# vim: softtabstop=2 shiftwidth=2 expandtab

# called by dracut
check() {
  #check for dropbear
  require_binaries dropbear || return 1
  
  return 0
}

depends() {
  echo network
  return 0
}

install() {
  #some initialization
  [[ -z "${dropbear_port}" ]] && dropbear_port=222
  [[ -z "${dropbear_acl}" ]] && dropbear_acl=/root/.ssh/authorized_keys
  local tmpDir=$(mktemp -d --tmpdir dracut-crypt-ssh.XXXX)
  trap '[ -n ${tmpDir} ] && [ -d ${tmpDir} ] && rm -rf ${tmpDir}' EXIT INT TERM
  local genConf="${tmpDir}/crypt-ssh.conf"
  local installConf="/etc/crypt-ssh.conf"
  local default_keytypes="rsa ecdsa ed25519"
  local relaxFailures convertSuccess

  if [[ -z "${dropbear_keytypes}" ]]; then
    dropbear_keytypes="${default_keytypes}"
  elif [[ "${dropbear_keytypes}" == "any" ]]; then
    dropbear_keytypes="${default_keytypes}"
    convertSuccess=0
    relaxFailures=1
  fi

  dropbear_keytypes="${dropbear_keytypes,,}"

  #start writing the conf for initramfs include
  echo -e "#!/bin/bash\n\n" > $genConf
  echo "keyTypes='${dropbear_keytypes}'" >> $genConf
  echo "dropbear_port='${dropbear_port}'" >> $genConf

  #go over different encryption key types
  for keyType in $dropbear_keytypes; do
    eval state=\$dropbear_${keyType}_key
    local msgKeyType="${keyType^^}"

    [[ -z "$state" ]] && state=GENERATE

    local osshKey="${tmpDir}/${keyType}.ossh"
    local dropbearKey="${tmpDir}/${keyType}.dropbear"
    local installKey="/etc/dropbear/dropbear_${keyType}_host_key"

    local output
    
    case ${state} in
      GENERATE )
        if ! output="$( ssh-keygen -t $keyType -f $osshKey -q -N "" -m PEM 2>&1 )" ; then
          if [ -z "${relaxFailures}" ]; then
            derror "SSH ${msgKeyType} key creation failed"
            derror "${output}"
            return 1
          else
            dwarn "SSH ${msgKeyType} key creation failed"
            dwarn "${output}"
            continue
          fi
        fi
        
        ;;
      SYSTEM )
        local sysKey=/etc/ssh/ssh_host_${keyType}_key
        if ! [[ -f ${sysKey} ]]; then
          if [ -z "${relaxFailures}" ]; then
            derror "Cannot locate a system SSH ${msgKeyType} host key in ${sysKey}"
            derror "Start OpenSSH for the first time or use ssh-keygen to generate one"
            return 1
          else
            dwarn "Cannot locate a system SSH ${msgKeyType} host key in ${sysKey}"
            dwarn "Start OpenSSH for the first time or use ssh-keygen to generate one"
            continue
          fi
        fi

        cp $sysKey $osshKey
        cp ${sysKey}.pub ${osshKey}.pub
        
        ;;
      * )
        if ! [[ -f ${state} ]]; then
          if [ -z "${relaxFailures}" ]; then
            derror "Cannot locate a system SSH ${msgKeyType} host key in ${state}"
            derror "Please use ssh-keygen to generate this key"
            return 1
          else
            dwarn "Cannot locate a system SSH ${msgKeyType} host key in ${state}"
            dwarn "Please use ssh-keygen to generate this key"
            continue
          fi
        fi
        
        cp $state $osshKey
        cp ${state}.pub ${osshKey}.pub
        ;;
    esac
    
    #convert the keys from openssh to dropbear format
    if ! output="$( dropbearconvert openssh dropbear $osshKey $dropbearKey 2>&1 )"; then
      if [ -z "${relaxFailures}" ]; then
        derror "dropbearconvert for ${msgKeyType} key failed"
        derror "${output}"
        return 1
      else
        dwarn "dropbearconvert for ${msgKeyType} key failed"
        dwarn "${output}"
        continue
      fi
    else
      convertSuccess="$(( convertSuccess + 1 ))"
    fi

    #install and show some information
    local keyFingerprint=$(ssh-keygen -l -f "${osshKey}")
    local keyBubble=$(ssh-keygen -B -f "${osshKey}")
    dinfo "Boot SSH ${msgKeyType} key parameters: "
    dinfo "  fingerprint: ${keyFingerprint}"
    dinfo "  bubblebabble: ${keyBubble}"
    inst $dropbearKey $installKey

    echo "dropbear_${keyType}_fingerprint='$keyFingerprint'" >> $genConf
    echo "dropbear_${keyType}_bubble='$keyBubble'" >> $genConf

  done

  if [[ -n "${relaxFailures}" ]] && [[ "${convertSuccess}" -eq 0 ]]; then
    derror "At least one SSH key must be generated and converted correctly"
    rm -rf "$tmpDir"
    return 1
  fi

  inst_rules "$moddir/50-udev-pty.rules"

  inst $genConf $installConf

  inst_hook pre-udev 99 "$moddir/dropbear-start.sh"
  inst_hook pre-pivot 05 "$moddir/dropbear-stop.sh"

  inst "${dropbear_acl}" /root/.ssh/authorized_keys

  #cleanup
  rm -rf $tmpDir
  
  #install the required binaries
  dracut_install pkill setterm
  inst_libdir_file "libnss_files*"

  #dropbear should always be in /sbin so the start script works
  local dropbear
  if dropbear="$(command -v dropbear 2>/dev/null)"; then
    inst "${dropbear}" /sbin/dropbear
  else
    derror "Unable to locate dropbear executable"
    return 1
  fi

  #install the required helpers
  inst "$moddir"/helper/console_auth /bin/console_auth
  inst "$moddir"/helper/console_peek.sh /bin/console_peek
  inst "$moddir"/helper/unlock /bin/unlock
  inst "$moddir"/helper/unlock-reap-success.sh /sbin/unlock-reap-success
}
