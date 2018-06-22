#!/bin/bash

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
  local keyTypes="rsa ecdsa"
  local genConf="${tmpDir}/crypt-ssh.conf"
  local installConf="/etc/crypt-ssh.conf"

  #start writing the conf for initramfs include
  echo -e "#!/bin/bash\n\n" > $genConf
  echo "keyTypes='${keyTypes}'" >> $genConf
  echo "dropbear_port='${dropbear_port}'" >> $genConf

  #go over different encryption key types
  for keyType in $keyTypes; do
    eval state=\$dropbear_${keyType}_key
    eval format=\$dropbear_${keyType}_format
    local msgKeyType=$(echo "$keyType" | tr '[:lower:]' '[:upper:]')

    [[ -z "$format" ]] && format=OPENSSH
    [[ -z "$state" ]] && state=GENERATE

    local osshKey="${tmpDir}/${keyType}.ossh"
    local dropbearKey="${tmpDir}/${keyType}.dropbear"
    local installKey="/etc/dropbear/dropbear_${keyType}_host_key"
    
    case ${state} in
      GENERATE )
        case ${format} in
          OPENSSH )
            ssh-keygen -t $keyType -f $osshKey -q -N "" || {
              derror "SSH ${msgKeyType} ${format} key creation failed"
              rm -rf "$tmpDir"
              return 1
            }
            ;;
          DROPBEAR )
            dropbearkey -t $keyType -f $dropbearKey || {
              derror "SSH ${msgKeyType} ${format} key creation failed"
              rm -rf "$tmpDir"
              return 1
            }
            dropbearkey -y -f $dropbearKey > ${dropbearKey}.pub || {
              derror "SSH ${msgKeyType} ${format} public key creation failed"
              rm -rf "$tmpDir"
              return 1
            }
            ;;
          * )
            derror "Unknown SSH key format ${format}"
            return 1
            ;;
        esac
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
        
        case ${format} in
          OPENSSH )
            cp $state $osshKey
            cp ${state}.pub ${osshKey}.pub
            ;;
          DROPBEAR )
            cp $state $dropbearKey
            cp ${state}.pub ${dropbearKey}.pub
            ;;
          * )
            derror "Unknown SSH key format ${format}"
            return 1
            ;;
        esac
        ;;
    esac
    
    #convert the keys to dropbear format
    case ${format} in
      OPENSSH )
        dropbearconvert openssh dropbear $osshKey $dropbearKey > /dev/null 2>&1 || {
          derror "dropbearconvert for ${msgKeyType} key failed"
          rm -rf "$tmpDir"
          return 1
        }

        #show some information
        local keyFingerprint=$(ssh-keygen -l -f "${osshKey}")
        local keyBubble=$(ssh-keygen -B -f "${osshKey}")
        dinfo "Boot SSH ${msgKeyType} key parameters: "
        dinfo "  fingerprint: ${keyFingerprint}"
        dinfo "  bubblebabble: ${keyBubble}"
        ;;
      DROPBEAR )
        #show some information
        local keyPublic=$(dropbearkey -y -f "${dropbearKey}")
        dinfo "Boot SSH ${msgKeyType} key parameters: "
        dinfo "  Public key: ${keyPublic}"
        ;;
      * )
        derror "Unknown SSH key format ${format} while converting keys"
        return 1
        ;;
    esac

    #install
    inst $dropbearKey $installKey

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
  DIRS="/usr/lib /usr/lib64 /lib64 /lib"
  for dir in ${DIRS}; do
    if [ -d ${dir} ]; then
      for check in `find ${dir} -name 'libnss_files.so*'`; do
        dracut_install ${check}
        break
      done
    fi
  done
  dracut_install pkill setterm
  inst $(which dropbear) /sbin/dropbear
  #install the required helpers
  inst "$moddir"/helper/console_auth /bin/console_auth
  inst "$moddir"/helper/console_peek.sh /bin/console_peek
  inst "$moddir"/helper/unlock /bin/unlock
  inst "$moddir"/helper/unlock-reap-success.sh /sbin/unlock-reap-success
}
