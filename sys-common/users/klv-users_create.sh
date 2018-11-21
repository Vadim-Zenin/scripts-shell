#!/bin/bash
#*******************************************************************************
# Author: Vadim Zenin https://gitlab.com/vzenin
# Date:   2017-02-09
#
# Usage: ./script01.sh
#
# Tested platform:
# Ubuntu, Kubuntu 16.04, 18.04, AWS linux, VyOS
#
# This code is made available as is, without warranty of any kind. The entire
# risk of the use or the results from the use of this code remains with the user.
#*******************************************************************************
PROGNAME=$(basename $0)
# PROGNAME=users_create.sh
VERSION="201808312126"
QUIET="0"

SHORTCOMPANY="abc"
MYHOME="/home"

################################################################################
# Functions
################################################################################
function f_log() {
  logger "${PROGNAME}: $1 $2 $3 $4 $5 $6 $7 $8"
  if [[ "${QUIET}" == "" ]] || [[ ${QUIET} -eq 0 ]]; then
    echo "$1 $2 $3 $4 $5 $6 $7 $8"
  fi
}

################################################################################
# MAIN
################################################################################
f_log "INFO: ${PROGNAME} started"
while [ $# -gt 0 ]
do
  case "$1" in
    -q)  QUIET=1;;
  esac
  shift
done

# perl: warning: Setting locale failed.
# perl: warning: Please check that your locale settings:
#         LANGUAGE = (unset),
#         LC_ALL = (unset),
#         LC_PAPER = "en_IE.UTF-8",
#         LC_ADDRESS = "en_IE.UTF-8",
#         LC_MONETARY = "en_IE.UTF-8",
#         LC_NUMERIC = "en_IE.UTF-8",
#         LC_TELEPHONE = "en_IE.UTF-8",
#         LC_IDENTIFICATION = "en_IE.UTF-8",
#         LC_MEASUREMENT = "en_IE.UTF-8",
#         LC_TIME = "en_IE.UTF-8",
#         LC_NAME = "en_IE.UTF-8",
#         LANG = "en_US.UTF-8"
#     are supported and installed on your system.
# perl: warning: Falling back to the standard locale ("C").

# Solution:
MYTMP=$(perl -e exit 2>&1 | awk '/Setting locale failed/ {print $0}' | wc -l)
if [[ "${MYTMP}" != "0" ]] ; then
  f_log "INFO: Fixing Setting locale failed issue for Ireland"
  locale-gen en_IE.UTF-8 
fi

[ $(getent group sudo) ] || groupadd --gid 27 sudo

declare -A USERS_ID=( 
  [myadmin]='1000'
  [utestone]='10001'
  [utesttwo]='10007'
  [backupadmin]='10901'
)
declare -A USERS_GECOS=( 
  [myadmin]='My Admin'
  [backupadmin]='Backup Admin'
  [utestone]='User Testone'
  [utesttwo]='User Testtwo'
)
declare -A USERS_GROUPS=( 
  [myadmin]="myadmin adm cdrom sudo dip plugdev lpadmin backup postgres"
  [backupadmin]="dip plugdev lpadmin adm root sudo backup postgres openldap sudoers"
  [utestone]="adm root sudo backup postgres openldap"
  [utesttwo]="adm root sudo backup postgres openldap"
)
declare -A USERS_KEYS=(
  [utestone]='ssh-rsa ... abc-biz-utestone__utestone@abc.com'
  [utesttwo]='ssh-rsa ... kv-prd-utesttwo__utesttwo@abc.com'
  )
declare -A SYSUSERS_KEYS=( 
  [myadmin]='ssh-rsa ... abc-biz-myadmin__helpdesk@abc.com'
  [backupadmin]='ssh-rsa ... abc-biz-backupadmin__helpdesk@abc.com'
)

#= Creating users
if [[ "$(grep VyOS /etc/issue | wc -l)" -eq "1" ]]; then
  f_log "We are working on VPN instance with VyOS"
  ADDUSEROPT="--disabled-password -q --gecos \"\""
elif [[ "$(grep "Amazon Linux" /etc/issue | wc -l)" -eq "1" ]]; then
  f_log "We are working on Amazon Linux instance"
  ADDUSEROPT=""
else
  ADDUSEROPT="--disabled-password --gecos \"\""
fi
echo "${ADDUSEROPT}"

for USERI in "${!USERS_ID[@]}"; do
  USERI=${USERI}
  MYVALUE=${USERS_ID[$USERI]};
  groupadd --gid ${MYVALUE} ${USERI}
  adduser --uid ${MYVALUE} --home ${MYHOME}/${USERI} --gid ${MYVALUE} ${ADDUSEROPT} ${USERI}
  cat /etc/passwd | grep ${USERI}
done

#= Updating users Gecos
for USERI in "${!USERS_ID[@]}"; do
  for USERG in "${!USERS_GECOS[@]}"; do
    if [[ "${USERI}" == "${USERG}" ]]; then
      MYVALUE=${USERS_GECOS[$USERG]};
      usermod --comment "${MYVALUE}" ${USERI}
      cat /etc/passwd | grep ${USERI}
    fi
  done
done

#= Updating users groups
for USERI in "${!USERS_ID[@]}"; do
  for USERGR in "${!USERS_GROUPS[@]}"; do
    if [[ "${USERI}" == "${USERGR}" ]]; then
      for MYGROUP in ${USERS_GROUPS[$USERGR]} ; do
        [ $(getent group ${MYGROUP}) ] && usermod -a -G ${MYGROUP} ${USERGR}
      done
      # groups ${USERGR}
    fi
  done
  for USERGR in "${!USERS_GROUPS[@]}"; do
    if [[ "${USERI}" == "${USERGR}" ]]; then
      groups ${USERGR}
    fi
  done
done

#= updating users ssh public keys
for USERI in "${!USERS_ID[@]}"; do
  for USERK in "${!USERS_KEYS[@]}"; do
    if [[ "${USERI}" == "${USERK}" ]]; then
      MYVALUE=${USERS_KEYS[$USERK]};
      USER_HOME=$(getent passwd ${USERI} | cut -f6 -d:)
      echo ${USER_HOME}
      if [[ -d ${USER_HOME} ]]; then
        mkdir -p -m 755 ${USER_HOME}/.ssh/tmp/
        if [[ -e ${USER_HOME}/.ssh/authorized_keys ]]; then
          cp ${USER_HOME}/.ssh/authorized_keys ${USER_HOME}/.ssh/authorized_keys.`date +%Y%m%d-%H%M`
        fi
        echo "${MYVALUE}" > ${USER_HOME}/.ssh/authorized_keys 
        chown -R ${USERK} ${USER_HOME}/.ssh
        chmod 644 ${USER_HOME}/.ssh/authorized_keys
        if [[ -f /usr/sbin/restorecon ]]; then
          restorecon -R -vv ${USER_HOME}/.ssh
        fi
        ls -la ${USER_HOME}/.ssh/authorized_keys
        cat ${USER_HOME}/.ssh/authorized_keys
      fi
    fi
  done
done

#= updating system users ssh public keys
for SYSUSER in "${!SYSUSERS_KEYS[@]}"; do
  USER_HOME=$(getent passwd ${SYSUSER} | cut -f6 -d:)
  echo ${USER_HOME}
  if [[ -d ${USER_HOME} ]]; then
  mkdir -p -m 755 ${USER_HOME}/.ssh
  echo "${SYSUSERS_KEYS[$SYSUSER]}" > ${USER_HOME}/.ssh/authorized_keys 
  chown -R ${SYSUSER} ${USER_HOME}/.ssh
  chmod 644 ${USER_HOME}/.ssh/authorized_keys
  if [[ -f /usr/sbin/restorecon ]]; then
    restorecon -R -vv ${USER_HOME}/.ssh
  fi
  ls -la ${USER_HOME}/.ssh/authorized_keys
  fi
done

#== Sudoers without password configuration
CONFDIRTMP="/etc/sudoers.d"; CONFFILENAMETMP="sudo"; CONFFILETMP=${CONFDIRTMP}/${CONFFILENAMETMP}
if [ -e ${CONFFILETMP} ] ; then
  cp ${CONFFILETMP} ${HOME}/${CONFFILENAMETMP}.`date +%Y%m%d-%H%M`
fi
# Configuring no password access per sudo group
cat > ${CONFFILETMP} << EOF
%sudo        ALL=(ALL)       NOPASSWD: ALL
utestone        ALL=(ALL)       NOPASSWD: ALL
EOF
# Configuring no password access per user
# for USERI in "${!USERS_ID[@]}"; do
#   for USERGR in "${!USERS_GROUPS[@]}"; do
#     if [[ "${USERI}" == "${USERGR}" ]]; then
#       for MYGROUP in ${USERS_GROUPS[$USERGR]} ; do
#         [ $(getent group ${MYGROUP}) ] && [ "${MYGROUP}" == "sudo" ] && echo "${USERGR}    ALL=(ALL)    NOPASSWD: ALL" >> ${CONFFILETMP}
#       done
#     fi
#   done
# done
chmod 440 ${CONFFILETMP}
cat ${CONFFILETMP} | grep -v "# *\|^$"

#= sudo permissions for deploysvc
MYUSERNAME="deploysvc"
f_log "INFO: Configuring ${MYUSERNAME} sudo permissions on $(hostname -s)"
CONFDIRTMP="/etc/sudoers.d" ; CONFFILENAMETMP="01${MYUSERNAME}" ; CONFFILETMP=${CONFDIRTMP}/${CONFFILENAMETMP}
if [ -e ${CONFFILETMP} ] ; then
  cp ${CONFFILETMP} ${HOME}/${CONFFILENAMETMP}.`date +%Y%m%d-%H%M`
fi
cat > ${CONFFILETMP}  << EOF
#=====Custom_config `date +%Y%m%d-%H%M`
Cmnd_Alias SERVICES = /sbin/service, /sbin/chkconfig, /bin/systemctl
Cmnd_Alias PROCESSES = /bin/nice, /bin/kill, /usr/bin/kill, /usr/bin/killall, /usr/bin/pkill
Cmnd_Alias WEBDEVELOP = /bin/find, /usr/bin/du, /bin/mv, /bin/chmod, /usr/sbin/nginx
Cmnd_Alias BUILD = /usr/local/bin/buildbot, /usr/bin/buildbot, /usr/local/bin/buildbot-worker, /usr/bin/buildbot-worker, /usr/local/bin/docker-compose, /usr/bin/docker, /bin/chown
Cmnd_Alias DEPLOY = /bin/find, /usr/bin/du, /bin/mv, /usr/local/bin/docker-compose, /usr/bin/docker, /bin/chown
#${MYUSERNAME}          ALL=(ALL)       ALL
${MYUSERNAME}          ALL=NOPASSWD: SERVICES, PROCESSES, WEBDEVELOP, DEPLOY
EOF
cat ${CONFFILETMP} | grep -v "# *\|^$"

f_log "INFO: ${PROGNAME} finished"
# END of Script

exit 0

