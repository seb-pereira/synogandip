#!/bin/bash
#
# synogandip __version__
# update gandi.net DNS record with your public IP
#
# Copyright (C) __year__ Sebastien Pereira
# https://github.com/seb-pereira/synogandip
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.
set -Eeuo pipefail

currentDir=$(dirname "$0")

function log {
  printf "[%s][INFO] %s\n" "$(date '+%Y-%m-%d-%H:%M:%S')" "$1"
}

function logError {
  printf "[%s][ERROR] %s\n" "$(date '+%Y-%m-%d-%H:%M:%S')" "$1"
}

function logTrace {
  if [ "$CONF_VERBOSE" = true ]; then
    printf "[%s][VERBOSE] %s\n" "$(date '+%Y-%m-%d-%H:%M:%S')" "$1"
  fi
}

function traceJSON {
  local json="${1:?missing json}"
  if [ "$CONF_VERBOSE" = true ]; then
    echo "${json}" | jq .
  fi
}

function loadConfigProperty {
  local configFile="${1:?config file path is missing}"
  local targetVariable="${2:?missing variable name}"
  local propName="${3:?missing property name}"
  local defaultValue="${4:-}"
  local _propertyValue

  _propertyValue="$(sed -n "s#^${propName}=##p" "${configFile}" | awk '{$1=$1};1')"
  if [ -z "${_propertyValue}" ]; then
      if [ -z "${defaultValue}" ]; then
        logError "missing required configuration property [${propName}]"
        exit 1
      else
        _propertyValue="${defaultValue}"
      fi
  fi

  # shellcheck disable=SC2116
  export "$(echo "$(echo "$targetVariable")=${_propertyValue}")"

  local padding='.........................'
  printf "%s %s %s %s\n" \
    "${propName}" \
    "${padding:${#propName}}" \
    "$([ "${propName}" != "gandi.api.key" ] && echo "${_propertyValue}" || echo "*********")" \
    "$([ "${_propertyValue}" == "${defaultValue}" ] && echo "(default)")"
}

function getPublicIP {
  local targetVariable="${1:?missing variable name}"
  local serviceUrl="${2:?missing public ip service url}"
  local _publicIp

  log "determining public IP ..."
  logTrace "${serviceUrl}"

  _publicIp="$(
    curl --silent --fail --show-error "${serviceUrl}"
  )"
  if [[ -z "${_publicIp}" ]]; then
    logError "unable to determine public IP"
    exit 1
  fi
  logTrace "${serviceUrl} => [${_publicIp}]"

  # shellcheck disable=SC2116
  export "$(echo "$(echo "$targetVariable")=${_publicIp}")"
}

function getDomainInfo {
  local targetVariable="${1:?missing variable name}"
  local apiUrl="${2:?missing api url}"
  local apiKey="${3:?missing api key}"
  local domain="${4:?missing domain}"
  local domainInfoUrl
  local _domainInfo

  domainInfoUrl="${apiUrl}/domains/${domain}"

  log "[${domain}] retrieving domain information ..."
  logTrace "[${domain}] ${domainInfoUrl}"

  _domainInfo="$(
    curl --silent --fail --show-error \
      --header "X-Api-Key: $apiKey" \
      "${domainInfoUrl}"
  )"
  if [[ -z "${_domainInfo}" ]]; then
    logError "unable to retrieve domain information"
    exit 1
  fi

  # shellcheck disable=SC2116
  export "$(echo "$(echo "$targetVariable")=${_domainInfo}")"

  traceJSON "${!targetVariable}"
}

function getZoneRecords {
  local targetVariable="${1:?missing variable name}"
  local apiKey="${2:?missing api key}"
  local domain="${3:?missing domain}"
  local zoneRecordsHref="${4:?missing zone record href}"
  local _zoneRecords

  logTrace "[${domain}] retrieving zone records information ..."
  logTrace "[${domain}] ${zoneRecordsHref}"

  _zoneRecords="$(
    curl --silent --fail --show-error \
      --header "X-Api-Key: $apiKey" \
      "${zoneRecordsHref}"
  )"

  if [[ -z "${_zoneRecords}" ]]; then
    logError "unable to retrieve zone records"
    exit 1
  fi

  # shellcheck disable=SC2116
  export "$(echo "$(echo "$targetVariable")=${_zoneRecords}")"

  traceJSON "${!targetVariable}"
}

function updateRecord {
  local apiKey="${1:?missing api key}"
  local domain="${2:?missing domain}"
  local zoneRecordsHref="${3:?missing zone record href}"
  local subDomain="${4:?missing sub-domain}"
  local ip="${5:?missing ip}"
  local ttl="${6:?missing ttl}"
  local apiResponse

  local recordUrl="${zoneRecordsHref}/${subDomain}/A"
  logTrace "[${subDomain}.${domain}] updating record with ip [${ip}] (ttl=${ttl})..."
  logTrace "${recordUrl}"

  if [[ "${CONF_DRY_RUN}" == true ]]; then
    return
  fi

  apiResponse="$(
    curl --silent --show-error \
      --header "Content-Type: application/json" \
      --header "X-Api-Key: ${apiKey}" \
      --data-binary '{
        "rrset_ttlv": "'"$ttl"'",
        "rrset_values": ["'"$ip"'"]
      }' \
      -X PUT  "${recordUrl}"
  )"

  if [[ -z "${apiResponse}" ]]; then
    logError "unable to update record"
    exit 1
  fi

  traceJSON "${apiResponse}"

  if [[ "$(echo "${apiResponse}"  | jq '.message | contains("DNS Record Created")')" == "false" ]]; then
    logError "unable to update the record (${recordUrl})"
    echo "${apiResponse}"  | jq .
    exit 1
  fi
}

function displayUsage {
  printf "synogandip - a DNS record updater [version __version__]\n\n"
  printf "usage: %s [options]\n" "$(basename "$0")"
  printf "  %-20s%s\n" "-f | --file <path>" "path to a configuration file. Default: synogandip.conf located in same folder."
  printf "  %-20s%s\n" "-v" "enable verbose mode: displays remote call responses and additional information."
  printf "  %-20s%s\n" "-d" "enable dry run mode: record is not created or updated. This option force the verbose mode."
  printf "  %-20s%s\n" "--version" "display the version."
}

function loadConfiguration {
  local configFile="${currentDir}/synogandip.conf"
  CONF_VERBOSE=false
  CONF_DRY_RUN=false
  echo "configFile: $configFile"

  local pargs=()
  while [[ $# -gt 0 ]]; do
    case $1 in
      -f|--file)
        configFile="${2:-}"
        shift # past argument
        shift # past value
        ;;
      -v|--verbose)
        CONF_VERBOSE=true
        shift # past argument
        ;;
      -d|--dry-run)
        CONF_DRY_RUN=true
        CONF_VERBOSE=true
        shift # past argument
        ;;
      -h|--help)
        displayUsage; exit 0
        ;;
      --version)
        echo "__version__"; exit 0;;
      -*)
        echo "Unknown option: $1"; usage; exit 1
        ;;
      *)
        pargs+=("$1"); shift
        ;;
    esac
  done

  echo "configFile: $configFile"

  if [[ ! -r "${configFile}" ]]; then
    logError "unable to read the configuration file: ${configFile}"
    exit 1
  fi

  echo "-------------------------------------------------------------------"
  echo " synogandip __version__"
  echo " update gandi.net DNS record with your public IP"
  if [[ "${CONF_DRY_RUN}" == true ]]; then
    echo ">>>>> DRY RUN option -d is enabled: record will NOT be created or updated <<<<<<"
    return
  fi
  echo "-------------------------------------------------------------------"
  # shellcheck disable=SC2116
  local -r absPath="$(echo "$(cd "$(dirname "${configFile}")"; pwd)/$(basename "${configFile}")")"
  log "loading configuration ${absPath} ..."
  # ------------------------------- target variable --- conf. prop. name --- default value ------------------------
  loadConfigProperty  "${absPath}" "CONF_API_KEY"      'gandi.api.key'
  loadConfigProperty  "${absPath}" "CONF_API_URL"      'gandi.api.url'       "https://dns.api.gandi.net/api/v5"
  loadConfigProperty  "${absPath}" "CONF_DOMAIN_NAME"  'domain.name'
  loadConfigProperty  "${absPath}" "CONF_SUB_DOMAIN"   'domain.record'
  loadConfigProperty  "${absPath}" "CONF_DEFAULT_TTL"  'domain.ttl'          1800
  loadConfigProperty  "${absPath}" "CONF_PUB_IP_SRV"   'public.ip.resolver'  "https://ifconfig.me"
  # ----------------------------------------------------------------------------------------------------------------
}

function main {
  loadConfiguration "$@"

  getPublicIP "IP_ADDRESS" \
    "${CONF_PUB_IP_SRV}"

  getDomainInfo "DOMAIN_INFO" \
    "${CONF_API_URL}" \
    "${CONF_API_KEY}" \
    "${CONF_DOMAIN_NAME}"

  local zoneRecordsHref
  zoneRecordsHref=$(
    echo "${DOMAIN_INFO}" | \
    jq -r '.zone_records_href'
  )

  getZoneRecords "ZONE_RECORDS" \
    "${CONF_API_KEY}" \
    "${CONF_DOMAIN_NAME}" \
    "${zoneRecordsHref}"

  local subDomainRecord
  subDomainRecord=$(
    echo "${ZONE_RECORDS}" | \
    jq -r --arg rrset_href "${zoneRecordsHref}/${CONF_SUB_DOMAIN}/A" '.[] | select(.rrset_href == $rrset_href)'
  )

  if [ -z "${subDomainRecord}" ]; then

    log "[${CONF_SUB_DOMAIN}.${CONF_DOMAIN_NAME}] record does not exist."

    updateRecord \
      "${CONF_API_KEY}" \
      "${CONF_DOMAIN_NAME}" \
      "${zoneRecordsHref}" \
      "${CONF_SUB_DOMAIN}" \
      "${IP_ADDRESS}" \
      "${CONF_DEFAULT_TTL}"

    log "[${CONF_SUB_DOMAIN}.${CONF_DOMAIN_NAME}] record successfully created."
  else
    logTrace "record found:"
    traceJSON "${subDomainRecord}"
    local recordIp
    recordIp=$(echo "${subDomainRecord}" | jq -r .rrset_values[])

    logTrace "[${IP_ADDRESS}] => public ip"
    logTrace "[${recordIp}] => record ip [${CONF_SUB_DOMAIN}.${CONF_DOMAIN_NAME}]"

    if [[ "${recordIp}" != "${IP_ADDRESS}" ]]; then
      logTrace "[${CONF_SUB_DOMAIN}.${CONF_DOMAIN_NAME}] record must be updated."

      local recordTTL
      recordTTL=$(echo "${subDomainRecord}" | jq -r .rrset_ttl)

      # update the record with the current public IP
      updateRecord \
        "${CONF_API_KEY}" \
        "${CONF_DOMAIN_NAME}" \
        "${zoneRecordsHref}" \
        "${CONF_SUB_DOMAIN}" \
        "${IP_ADDRESS}" \
        "${recordTTL}"

      log "[${CONF_SUB_DOMAIN}.${CONF_DOMAIN_NAME}] record successfully updated."
    else
      log "[${CONF_SUB_DOMAIN}.${CONF_DOMAIN_NAME}] no change required."
    fi
  fi

  log "[${CONF_SUB_DOMAIN}.${CONF_DOMAIN_NAME}] operation completed."

  if [[ "${CONF_DRY_RUN}" == true ]]; then
    echo ">>> DRY RUN MODE was enabled <<<"
  fi
}

main "$@"
