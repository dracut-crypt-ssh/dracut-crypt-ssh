#!/bin/bash

# called by dracut
check() {
  if [[ "${crypt_ssh_use_sshd}" = "yes" ]]; then
    require_binaries sshd || return 1
  else
    #check for dropbear
    require_binaries dropbear || return 1
  fi
  
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
  local keyTypes="rsa ecdsa"
  local genConf="${tmpDir}/crypt-ssh.conf"
  local installConf="/etc/crypt-ssh.conf"

  #start writing the conf for initramfs include
  echo -e "#!/bin/bash\n\n" > $genConf
  echo "keyTypes='${keyTypes}'" >> $genConf
  echo "dropbear_port='${dropbear_port}'" >> $genConf
  if [[ "${crypt_ssh_use_sshd}" = "yes" ]]; then
    echo "crypt_ssh_use_sshd=yes" >> $genConf
  fi

  #go over different encryption key types
  for keyType in $keyTypes; do
    eval state=\$dropbear_${keyType}_key
    local msgKeyType=$(echo "$keyType" | tr '[:lower:]' '[:upper:]')

    [[ -z "$state" ]] && state=GENERATE

    local osshKey="${tmpDir}/${keyType}.ossh"
    local dropbearKey="${tmpDir}/${keyType}.dropbear"
    local installKey
    if [[ "${crypt_ssh_use_sshd}" = "yes" ]]; then
      installKey="/etc/ssh/ssh_host_${keyType}_key"
    else
      installKey="/etc/dropbear/dropbear_${keyType}_host_key"
    fi
    
    case ${state} in
      GENERATE )
        ssh-keygen -t $keyType -f $osshKey -q -N "" || {
          derror "SSH ${msgKeyType} key creation failed"
          rm -rf "$tmpDir"
          return 1
        }
        
        ;;
      SYSTEM )
        local sysKey=/etc/ssh/ssh_host_${keyType}_key
        [[ -f ${sysKey} ]] || {
          derror "Cannot locate a system SSH ${msgKeyType} host key in ${sysKey}"
          derror "Start OpenSSH for the first time or use ssh-keygen to generate one"
          return 1
        }

        cp $sysKey $osshKey
        cp ${sysKey}.pub ${osshKey}.pub
        
        ;;
      * )
        [[ -f ${state} ]] || {
          derror "Cannot locate a system SSH ${msgKeyType} host key in ${state}"
          derror "Please use ssh-keygen to generate this key"
          return 1
        }
        
        cp $state $osshKey
        cp ${state}.pub ${osshKey}.pub
        ;;
    esac
    
    if [[ "${crypt_ssh_use_sshd}" = "yes" ]]; then
      inst $osshKey $installKey
    else
      #convert the keys from openssh to dropbear format
      dropbearconvert openssh dropbear $osshKey $dropbearKey > /dev/null 2>&1 || {
        derror "dropbearconvert for ${msgKeyType} key failed"
        rm -rf "$tmpDir"
        return 1
      }
      inst $dropbearKey $installKey
    fi

    #show some information
    local keyFingerprint=$(ssh-keygen -l -f "${osshKey}")
    local keyBubble=$(ssh-keygen -B -f "${osshKey}")
    dinfo "Boot SSH ${msgKeyType} key parameters: "
    dinfo "  fingerprint: ${keyFingerprint}"
    dinfo "  bubblebabble: ${keyBubble}"

    echo "dropbear_${keyType}_fingerprint='$keyFingerprint'" >> $genConf
    echo "dropbear_${keyType}_bubble='$keyBubble'" >> $genConf

  done

  inst_rules "$moddir/50-udev-pty.rules"

  inst $genConf $installConf

  inst_hook pre-udev 99 "$moddir/dropbear-start.sh"
  inst_hook pre-pivot 05 "$moddir/dropbear-stop.sh"

  inst "${dropbear_acl}" /root/.ssh/authorized_keys

  #cleanup
  rm -rf $tmpDir
  
  #install the required binaries
  dracut_install pkill setterm /lib64/libnss_files.so.2
  if [[ "${crypt_ssh_use_sshd}" = "yes" ]]; then
    inst $(which sshd) /sbin/sshd
    inst "$moddir"/sshd_config /etc/ssh/sshd_config
  else
    inst $(which dropbear) /sbin/dropbear
  fi
  #install the required helpers
  inst "$moddir"/helper/console_auth /bin/console_auth
  inst "$moddir"/helper/console_peek.sh /bin/console_peek
  inst "$moddir"/helper/unlock /bin/unlock
  inst "$moddir"/helper/unlock-reap-success.sh /sbin/unlock-reap-success
}
