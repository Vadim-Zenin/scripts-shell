#!/bin/bash
#*******************************************************************************
# Purpose: To read sensors data on Domoticz windows and check if the windows
#           are closed. 
# Author:  Vadim Zenin https://gitlab.com/vzenin
# Date:    2018-02-04
#
# Usage: ./script01.sh
#
# Tested platform:
# Ubuntu 16.04
#
# This code is made available as is, without warranty of any kind. The entire
# risk of the use or the results from the use of this code remains with the user.
#*******************************************************************************

# declare -i Ensuite_bedroom_Window_Left_IDX
# declare    Ensuite_bedroom_Window_Left_Status
declare    ENVIRONMENT
declare    PROGNAME
declare    VERSION
declare    QUIET
declare    SCRIPTLOCK
# declare    DRY_RUN
# declare    DomoURL
# declare    PROGNAME_exit_code_vname

# PROGNAME=$(basename $0)
export ENVIRONMENT="prd"
export PROGNAME=windows_open_check.${ENVIRONMENT}.sh
VERSION="201802041426"
export QUIET="0"
script_dependencies=('jq')

################################################################################
# Functions
################################################################################
if [[ -e all_common_functions.prd.sh ]]; then
  source all_common_functions.prd.sh
else
  f_exit_error "File all_common_functions.prd.sh does not exists"
fi

function f_usage {
  echo "
  ${PROGNAME}:
    Read sensors data on Domoticz and check if windows and doors are closed.

  Usage: .${PROGNAME} [OPTIONS]

    Options:

    -c, <file>  : specify configuration file containing password to be
                used. This defaults to windows_open_check.${ENVIRONMENT}.config.sh
    -q  0/1     : if= 1 quiet. suppress console messages.
    -n,         :perform a trial run with no changes made
    -h          : display this help

    Examples:
    pushd ~/domoticz/scripts/bash
    ./windows_open_check.prd.sh -c windows_open_check.level0.config.prd.sh
              
  "
}     

################################################################################
# MAIN
################################################################################
source all_common_functions.${ENVIRONMENT}.sh
f_log "INFO: ${PROGNAME} started"

### process command line options
while getopts "c:qh" opt 
do
  case $opt in
    c) Config_file="${OPTARG}" ;;
    q) QUIET=1 ;;
    # n) DRY_RUN=1
    # # echo "-n was triggered, Parameter: ${OPTARG}" >&2 
    # ;;
    h) f_usage 
      f_exit_graceful ;;
    \?) echo "unknown option"
      f_usage 
      f_exit_error ;;
    # :)
    #   echo "Option -$OPTARG requires an argument." >&2
    #   f_exit_error ;;
    *)  f_usage
      f_exit_error ;;
  esac
done
shift $((OPTIND-1))  #This tells getopts to move on to the next argument.

f_log "INFO: \${Config_file}: ${Config_file}"
echo "DEBUG: QUIET: ${QUIET}"
f_log "INFO: \${QUIET}: ${QUIET}"
# f_log "INFO: \${DRY_RUN}: ${DRY_RUN}"

f_check_script_dependencies "${script_dependencies[@]}"

### Use default config file if the config was not specified in options
if [[ "${Config_file}" == "" ]]; then
  Config_file="${PROGNAME%.*}.config.${PROGNAME##*.}"
  # echo "DEBUG: \${Config_file}: ${Config_file}"
fi

### Read configuration
f_read_config "${Config_file}"
echo "DEBUG: DomoURL: ${DomoURL}"
echo "DEBUG: DomoRunDir: ${DomoRunDir}"

SCRIPTLOCK="${DomoRunDir}/${PROGNAME}_in_progress"
echo "DEBUG: SCRIPTLOCK: ${SCRIPTLOCK}"

echo "Current exit"; f_exit_graceful;

f_stopping_previous_script
echo "Current exit"; exit 0;
f_writing_script_pid_to_file "${SCRIPTLOCK}"

# # List all variables
# curl -s "${DomoURL}/json.htm?type=command&param=getuservariables"

# # List one variable
# curl -s "${DomoURL}/json.htm?type=command&param=getuservariable&idx=9"
# curl -s "${DomoURL}/json.htm?type=command&param=getuservariable&idx=${HeatingTempEnsuiteMin_IDX}" | grep "\"Value\" :" | awk '{print $3}' | sed 's/\"//g' | sed 's/\,//g'

# Get Status of Domoticz switches and sensors
# Ensuite_bedroom_Window_Left_Status=$(curl -s "${DomoURL}/json.htm?type=devices&rid=${Ensuite_bedroom_Window_Left_IDX}" | grep "\"Status\" :" | awk '{print $3}' | sed 's/\"//g' | sed 's/\,//g')
# f_log "DEBUG: \${Ensuite_bedroom_Window_Left_Status}: ${Ensuite_bedroom_Window_Left_Status}"

RETURN_MESSAGE=""
for AITEM in ${ASENSORS[@]} ; do
  # echo \${AITEM}: ${AITEM}
  # curl -s "${DomoURL}/json.htm?type=devices&rid=${AITEM}" | grep "\"Status\" :" | awk '{print $3}' | sed 's/\"//g' | sed 's/\,//g'
# # Test part start
# if [[ ${AITEM} != 65 ]]; then
#   ASTATUS=$(curl -s "${DomoURL}/json.htm?type=devices&rid=${AITEM}" | grep "\"Status\" :" | awk '{print $3}' | sed 's/\"//g' | sed 's/\,//g')
# else
#   ASTATUS=Open
# fi
# # Test part end
  ASTATUS=$(curl -s "${DomoURL}/json.htm?type=devices&rid=${AITEM}" | grep "\"Status\" :" | awk '{print $3}' | sed 's/\"//g' | sed 's/\,//g')
  f_log "INFO: Window_IDX ${AITEM} Status: ${ASTATUS}"
if [[ ${ASTATUS} == Open ]]; then
  ANAME=$(curl -s "${DomoURL}/json.htm?type=devices&rid=${AITEM}" | grep "\"Name\" :" | awk '{print $3}' | sed 's/\"//g' | sed 's/\,//g')
  RETURN_MESSAGE="${ANAME}_is_open.${RETURN_MESSAGE}"
fi
done

f_exit_graceful

# Get value of Domoticz variable ${PROGNAME}_exit_code
# DomoURL="https://zh1sh.kolovit.com:8443"
PROGNAME_exit_code_vname=${PROGNAME}_exit_code
if [[ $(curl -s "${DomoURL}/json.htm?type=command&param=getuservariables"  | grep ${PROGNAME_exit_code_vname}) != "" ]]; then
  f_log "INFO: User variable $(curl -s "${DomoURL}/json.htm?type=command&param=getuservariables"  | grep "${PROGNAME_exit_code_vname}" | awk '{print $3}' | sed 's/\"//g' | sed 's/\,//g') exists."
else
  f_log "INFO: ${PROGNAME_exit_code_vname} does not exist."
  # Store a new Domoticz user variable
  # user variable type
  # 0 = Integer, e.g. -1, 1, 0, 2, 10 
  # 1 = Float, e.g. -1.1, 1.2, 3.1
  # 2 = String
  # 3 = Date in format DD/MM/YYYY
  # 4 = Time in 24 hr format HH:MM
  curl -s "${DomoURL}/json.htm?type=command&param=saveuservariable&vname=${PROGNAME_exit_code_vname}&vtype=0&vvalue=32"
fi
PROGNAME_exit_vreturn=${PROGNAME}_return_message
if [[ $(curl -s "${DomoURL}/json.htm?type=command&param=getuservariables"  | grep ${PROGNAME_exit_vreturn}) != "" ]]; then
  f_log "INFO: User variable $(curl -s "${DomoURL}/json.htm?type=command&param=getuservariables"  | grep "${PROGNAME_exit_vreturn}" | awk '{print $3}' | sed 's/\"//g' | sed 's/\,//g') exists."
else
  f_log "INFO: ${PROGNAME_exit_vreturn} does not exist."
  # Store a new Domoticz user variable
  # user variable type
  # 0 = Integer, e.g. -1, 1, 0, 2, 10 
  # 1 = Float, e.g. -1.1, 1.2, 3.1
  # 2 = String
  # 3 = Date in format DD/MM/YYYY
  # 4 = Time in 24 hr format HH:MM
  curl -s "${DomoURL}/json.htm?type=command&param=saveuservariable&vname=${PROGNAME_exit_vreturn}&vtype=2&vvalue="
fi

# # Searching User Variable IDX by Name (not used for now)
# # curl -s "${DomoURL}/json.htm?type=command&param=getuservariables" | jq -r '.result[] | select(.Name == "floor1_open_windows_check.sh_exit_code") | .idx'
# PROGNAME_exit_code_IDX=$(curl -s "${DomoURL}/json.htm?type=command&param=getuservariables" | jq -r --arg VarName "${PROGNAME_exit_code_vname}" '.result[] | select(.Name == $VarName) | .idx')
# f_log "INFO: ${PROGNAME_exit_code_vname} IDX: ${PROGNAME_exit_code_IDX}"

if [[ ${RETURN_MESSAGE} == "" ]]; then
  RETURN_MESSAGE="Windows_are_closed_on_level1"
  f_log "RETURN: ${RETURN_MESSAGE}"
  # Update an existing Domoticz user variable ${PROGNAME_exit_code_vname}
  curl -s "${DomoURL}/json.htm?type=command&param=updateuservariable&vname=${PROGNAME_exit_code_vname}&vtype=0&vvalue=0"
  curl -s "${DomoURL}/json.htm?type=command&param=updateuservariable&vname=${PROGNAME_exit_vreturn}&vtype=2&vvalue="${RETURN_MESSAGE}""
  f_return_pozitive
else
  # RETURN_MESSAGE="${RETURN_MESSAGE}"
  f_log "RETURN: ${RETURN_MESSAGE}"
 # Update an existing Domoticz user variable ${PROGNAME_exit_code_vname}
  curl -s "${DomoURL}/json.htm?type=command&param=updateuservariable&vname=${PROGNAME_exit_code_vname}&vtype=0&vvalue=9"
  curl -s "${DomoURL}/json.htm?type=command&param=updateuservariable&vname=${PROGNAME_exit_vreturn}&vtype=2&vvalue="${RETURN_MESSAGE}""
  f_return_negative
fi

rm -f ${SCRIPTLOCK}
f_return_pozitive
# END of Script

# # Configure the job in domoticz cron
# CONFDIRTMP="/var/spool/cron/crontabs"; CONFFILENAMETMP="domoticz"; CONFFILETMP=${CONFDIRTMP}/${CONFFILENAMETMP}
# if [ -e ${CONFFILETMP} ] ; then
#   sudo -u domoticz cp ${CONFFILETMP} ${HOME}/cron.bak.`date +%Y%m%d-%H%M`
# fi
# perl -pi -e 's/^(.*?)(floor1_heating_by_schedule.sh)(.*)//' ${CONFFILETMP}
# perl -pi -e 's/^(MAILTO)(.*)//' ${CONFFILETMP}
# sed -i "/^\s*$/d" ${CONFFILETMP}  # remove empty lines
# # `/bin/date +%Y%m%d-%H%M`
# cat >> ${CONFFILETMP} << EOF
# # MAILTO="vadims.zenins@gmail.com"
# 54 21-23 * * *  if [ -e /opt/domoticz/domoticz/scripts/bash/floor1_heating_by_schedule.sh ] ; then /opt/domoticz/domoticz/scripts/bash/floor1_heating_by_schedule.sh; fi >/dev/null 2>&1
# 54 0-8 * * *  if [ -e /opt/domoticz/domoticz/scripts/bash/floor1_heating_by_schedule.sh ] ; then /opt/domoticz/domoticz/scripts/bash/floor1_heating_by_schedule.sh; fi >/dev/null 2>&1
# EOF
# chown domoticz:domoticz ${CONFFILETMP}
# chmod 600 ${CONFFILETMP}
# # cat ${CONFFILETMP}
# crontab -u domoticz -l

