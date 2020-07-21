#!/bin/bash
# backup-user-home.sh
# https://www.linkedin.com/in/vadimzenin/
# Tested on Ubuntu 18.04

################################################################################
# Functions
################################################################################
function f_log() {
	logger "${PROGNAME}: $@"
	if [[ "${QUIET}" == "" ]] || [[ ${QUIET} -eq 0 ]]; then
		printf "$@\n"
	fi
}

function f_printf_error() { 
  printf "ERROR: $@\n" 1>&2
}

function f_calculate_period {
	DATESTAMP=$(date +%Y%m%d-%H%M)
	DAY=$(date +"%d")
	DAYOFWEEK=$(date +"%A")
	mkdir -p -m 770 ${BACKUP_DIR} && chown :backup ${BACKUP_DIR}
	PERIOD=${1-day}
	if [ ${DAY} = "01" ]; then
		PERIOD="month"
	elif [ ${DAYOFWEEK} = "Sunday" ]; then
		PERIOD="week"
	else
		PERIOD="day"
	fi
	f_log "INFO: Selected period: ${PERIOD}"
	if [[ ! -d ${BACKUP_DIR}/${PERIOD} ]]; then
		mkdir -p -m 775 ${BACKUP_DIR}/${PERIOD}/ && chown :backup ${BACKUP_DIR}/${PERIOD}
		f_log "INFO: Creating ${BACKUP_DIR}/${PERIOD}"
		f_log "INFO: $(ls -l ${BACKUP_DIR}/)"
	fi
	if [[ ! -d ${BACKUP_DIR}/${PERIOD} ]]; then
		f_printf_error "Cannot create ${BACKUP_DIR}/${PERIOD}, script failed."
		exit 4
	fi
}

function f_create_backup {
	TAR_OUT_FILE="$(hostname -s)-${USER_LOGIN}-home-dir-${MYDATE}.tar.gz"
	if [[ -f ${BACKUP_DIR}/${PERIOD}/${TAR_OUT_FILE}	]]; then
		rm ${BACKUP_DIR}/${PERIOD}/${TAR_OUT_FILE}
		f_log "INFO: ${BACKUP_DIR}/${PERIOD}/${TAR_OUT_FILE} deleted"
	fi
	# Check if files/directories exist
	if [[ -e ${USER_HOME_DIR} ]]; then
		f_log "DEBUG: \${USER_HOME_DIR} : ${USER_HOME_DIR}"
		OPTIONS="${USER_HOME_DIR}"
		${NICE_LEVEL} /bin/tar -zcf ${BACKUP_DIR}/${PERIOD}/${TAR_OUT_FILE} ${OPTIONS}
		if [ $? -ne 0 ] || [ ! -f ${BACKUP_DIR}/${PERIOD}/${TAR_OUT_FILE} ]; then
			f_printf_error "Tar archiving ${BACKUP_DIR} failed, archive ${BACKUP_DIR}/${PERIOD}/${TAR_OUT_FILE} removed"
			rm ${BACKUP_DIR}/${PERIOD}/${TAR_OUT_FILE}
			exit 8
		else
			RETURN="0"
		fi
		f_log "INFO: ${BACKUP_DIR}/${PERIOD}/${TAR_OUT_FILE} created successfully"
		chown -R :backup ${BACKUP_DIR}
		f_log "INFO: $(ls -l ${BACKUP_DIR}/${PERIOD}/${TAR_OUT_FILE})"
	else
		f_log "WARNING: ${USER_HOME_DIR} does not exists."
	fi
}

function f_select_users_and_backup {
	while IFS='' read -r LINE || [[ -n "${LINE}" ]]; do
		# f_log "DEBUG: \${LINE} : ${LINE};"
		USER_LOGIN=$(echo ${LINE} | awk -F'[:]' '{print $1}')
		# f_log "DEBUG: processing user: ${USER_LOGIN}"
		USER_HOME_DIR=$(echo ${LINE} | awk -F'[:]' '{print $6}')
		USER_SHELL=$(echo ${LINE} | awk -F'[:]' '{print $7}')
		# f_log "DEBUG: \${USER_SHELL} : ${USER_SHELL};"
		# if [[ ${USER_LOGIN} =~ ^.*?test.* ]]; then
		if [[ ! -z ${USER_HOME_DIR} ]] && [[ ! ${USER_SHELL} =~ ^.*?nologin ]] && [[ ! ${USER_SHELL} =~ ^.*?false ]] && [[ ! ${USER_HOME_DIR} =~ ^/bin ]]; then
			f_log "INFO: processing user ${USER_LOGIN} home directory: ${USER_HOME_DIR}"
			f_create_backup
		fi
	done < "/etc/passwd"
}

function f_cleaning_backups {
	f_log "INFO: Cleaning backups older than days monthly: ${KEEP_BACK_MONTH}; weekly: ${KEEP_BACK_WEEK}; dayly: ${KEEP_BACK_DAY}"
	if [[ -d ${BACKUP_DIR}/month ]]; then
		eval find ${BACKUP_DIR}/month/ -type f -name "*.tar.gz" -or -name "*.tar" -mtime +${KEEP_BACK_MONTH} -delete | f_log
	fi
	if [[ -d ${BACKUP_DIR}/week ]]; then
		eval find ${BACKUP_DIR}/week/ -type f -name "*.tar.gz" -or -name "*.tar" -mtime +${KEEP_BACK_WEEK} -delete | f_log
	fi
	if [[ -d ${BACKUP_DIR}/day ]]; then
		eval find ${BACKUP_DIR}/day/ -type f -name "*.tar.gz" -or -name "*.tar" -mtime +${KEEP_BACK_DAY} -delete | f_log
	fi
}
################################################################################
# MAIN
################################################################################

f_log "\nINFO: backup-user-home.sh started\n"

VERSION="202007212239"
QUIET="0"
BACKUP_DIR="/var/backup/users-homes"
# keep backups days
KEEP_BACK_MONTH="365"
KEEP_BACK_WEEK="60"
KEEP_BACK_DAY="14"
MYDATE=$(/bin/date +%Y%m%d-%H%M)
NICE_LEVEL="nice -n 10"

f_calculate_period

f_select_users_and_backup

f_cleaning_backups

f_log "\nINFO: backup-user-home.sh finished with code ${RETURN}\n"
exit ${RETURN}
# END of Script





# Copy the file to /usr/local/sbin/
# Configure backup job in root cron
CONFDIRTMP="/var/spool/cron/crontabs"; CONFFILENAMETMP="root"; CONFFILETMP=${CONFDIRTMP}/${CONFFILENAMETMP}
if [ -e ${CONFFILETMP} ] ; then
  cp ${CONFFILETMP} ${HOME}/cron.bak.$(date +%Y%m%d-%H%M)
fi
perl -pi -e 's/^(.*?)(backup-user-home)(.*)//' ${CONFFILETMP}
perl -pi -e 's/^(MAILTO)(.*)//' ${CONFFILETMP}
sed -i "/^\s*$/d" ${CONFFILETMP}  # remove empty lines
# $(/bin/date +%Y%m%d-%H%M)
cat >> ${CONFFILETMP} << EOF
MAILTO="support@example.com"
30 2 * * *  if [ -f /usr/local/sbin/backup-user-home.sh ] ; then perl -le 'sleep rand 600' && /usr/local/sbin/backup-user-home.sh ; fi >/dev/null 2>&1
EOF
chown root:root ${CONFFILETMP}
chmod 600 ${CONFFILETMP}
# cat ${CONFFILETMP}
crontab -u root -l
ls -l /usr/local/sbin
