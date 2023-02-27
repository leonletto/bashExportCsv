#!/usr/bin/env bash
set -o errexit
set -o nounset
set -o pipefail
if [[ "${TRACE-0}" == "1" ]]; then set -o xtrace; fi

if [[ -d submodules/bashLogger ]]; then
    source submodules/bashLogger/logger.sh
    log_level INFO
fi

export_csv(){
    # $1 - Required - the response from the api call or other source of json data
    # $2 - Required - the name of the csv file to export to
    # $3 - Optional - the name of the Objects if there is a Named array in an Object
    # eg { "Devices": [ { "Device": { "Uuid": "uuid1", "Name": "name1" } }, { "Device": { "Uuid": "uuid2", "Name": "name2" } } ] }
    # if you are just passing an array, then pass "" or you can omit this if you are only passing an array and a csvfile
    # $4 - Optional - If there are multiple responses that you are going to pass and you want to append to the csv file, then pass "Append"
    # Otherwise if there are other options added, pass "" to indicate that this is the ONLY response
    # Required if "Append" - If you are going to pass multiple responses ( using "Append" ), then you must pass "Done" when you pass the last response
    # Required if "Append" - If you are going to pass multiple responses ( using "Append" ), then you should pass an array containing the name of the
    # field OR fields that you want to use to uniquely identify the record so that duplicates are not added to the csv file when you append
    # #5 - Optional - the Array containing the name of the field OR fields that you want to use to uniquely identify the record eg ("Uuid") or ("Uuid" "Name")
    # $6 - Optional - the name (full path) of the database file to use to hold the data if you want to preserve the data
    # $7 - Optional - the name of the table to use to hold the flattened data if you want to preserve the flattened data

    # The user will give the csv file to export to in the command.  If the file does not exist it will be created
    tmp_Response="$1"
    csvFile="$2"

    if [[ "${3:-}" ]]; then
        tmp_ObjectName="$3"
    else
        tmp_ObjectName=""
    fi
    if [[ "${4:-}" ]]; then
        tmp_Append="$4"
    else
        tmp_Append=""
    fi
    if [[ "${5:-}" ]]; then
        tmp_PK="$5"
    else
        tmp_PK=""
    fi
    if [[ "${6:-}" ]]; then
        tmp_Db="$6"
    else
        tmp_Db=""
    fi
    if [[ "${7:-}" ]]; then
        tmp_Table="$7"
    else
        tmp_Table=""
    fi

    # check for logging function
    if [[ "$(type -t log_info)" == "alias" ]]; then
        logging="true"
    else
        logging="false"
    fi

    if [[ -f "${csvFile}" ]]; then
        if [[ "${tmp_Append}" == "Append" ]] || [[ "${tmp_Append}" == "Done" ]]; then
            if [[ "$logging" == "true" ]]; then
               log_info "Appending to ${csvFile}"
            else
                echo "Appending to ${csvFile}"
            fi
        else
            if [[ "$logging" == "true" ]]; then
                log_info "Deleting ${csvFile}"
            else
                echo "Deleting ${csvFile}"
            fi
            rm "${csvFile}"
            touch "${csvFile}"
        fi
    else
        if [[ "$logging" == "true" ]]; then
            log_info "Creating ${csvFile}"
        else
            echo "Creating ${csvFile}"
        fi
        touch "${csvFile}"
    fi

    # Next create a temporary database to hold the data
    if [[ -z "${tmp_Db}" ]]; then
        if [[ "${tmp_Append}" == "Append" ]]; then
            if [[ "${AppendingDb:-}" ]]; then
                tmpDb="$AppendingDb"
                if [[ "$logging" == "true" ]]; then
                    log_info "Appending to ${tmpDb}"
                else
                    echo "Appending to ${tmpDb}"
                fi
            else
                tmpDb=$(mktemp -t tmp.XXXXXXXXXX)
                newTmpDb="$tmpDb.db"
                mv "$tmpDb" "$newTmpDb"
                tmpDb="$newTmpDb"
                export AppendingDb="$tmpDb"
                if [[ "$logging" == "true" ]]; then
                    log_info "Appending to ${tmpDb}"
                else
                    echo "Appending to ${tmpDb}"
                fi
            fi
        elif [[ "${tmp_Append}" == "Done" ]]; then
            tmpDb="$AppendingDb"
            if [[ "$logging" == "true" ]]; then
                log_info "Done appending to ${tmpDb}"
            else
                echo "Done appending to ${tmpDb}"
            fi
            unset AppendingDb
        else
            tmpDb=$(mktemp -t tmp.XXXXXXXXXX)
            newTmpDb="$tmpDb.db"
            mv "$tmpDb" "$newTmpDb"
            tmpDb="$newTmpDb"
            if [[ "$logging" == "true" ]]; then
                log_info "tmpDb: $tmpDb"
            else
                echo "tmpDb: $tmpDb"
            fi
        fi
    else
        tmpDb="$tmp_Db"
        if [[ "$logging" == "true" ]]; then
            log_info "tmpDb: $tmpDb"
        else
            echo "tmpDb: $tmpDb"
        fi
    fi

    # Create a temporary json file to hold the scratch data
    tmpJson=$(mktemp -t tmp.XXXXXXXXXX)
    newTmpJson="$tmpJson.json"
    mv "$tmpJson" "$newTmpJson"
    tmpJson="$newTmpJson"
#    if [[ "$logging" == "true" ]]; then
#        log_info "tmpJson: $tmpJson"
#    else
#        echo "tmpJson: $tmpJson"
#    fi

    if [[ -f $tmpJson ]]; then
        rm "$tmpJson"
        touch "$tmpJson"
    fi

    # check the response to see if it is an array or an object
    if [[ "$(echo "${tmp_Response}" | jq -r 'type' 2> /dev/null)" == "array" ]]; then
        if [[ "$logging" == "true" ]]; then
            log_info "Response is an array"
        else
            echo "Response is an array"
        fi
    elif [[ "$(echo "${tmp_Response}" | jq -r 'type' 2> /dev/null)" == "object" ]]; then
        if [[ "$logging" == "true" ]]; then
            log_info "Response is an object"
        else
            echo "Response is an object"
        fi
    else
        if [[ "$logging" == "true" ]]; then
            log_error "you passed $tmp_Response"
            log_error "You must pass an array or an object to this function as the first parameter"
            log_error "eg: {\"ArrayName\": [{Object1}, {Object2}, {Object3}]}"
        else
            echo "you passed $tmp_Response"
            echo "You must pass an array or an object to this function as the first parameter"
            echo "eg: {\"ArrayName\": [{Object1}, {Object2}, {Object3}]}"
        fi
        exit 1
    fi

    # if the user passed in a name of an object, then we need to flatten the NAMED array of objects else just flatten the array of objects
    if [[ -z "${tmp_ObjectName}" ]]; then
        echo "[" > "$tmpJson"
        x=0
        totalObjects=$(echo "${tmp_Response}" | jq ". | length")

        echo "${tmp_Response}" | jq -c '.[]| [paths(scalars) as $path | {"key": $path | join("_"), "value": getpath($path)}] | from_entries' | while read -r item; do
            if [[ $x -lt $((totalObjects-1)) ]]; then
                echo "${item}," >> "$tmpJson"
            else
                echo "${item}" >> "$tmpJson"
            fi
            x=$((x+1))
        done
        echo "]" >> "$tmpJson"
    else
        echo "[" > "$tmpJson"
        x=0
        totalObjects=$(echo "${tmp_Response}" | jq ".${tmp_ObjectName} | length")
        echo "${tmp_Response}" | jq -c '.'"${tmp_ObjectName}"'[] | [paths(scalars) as $path | {"key": $path | join("_"), "value": getpath($path)}] | from_entries' | while read -r item; do
            if [[ $x -lt $((totalObjects-1)) ]]; then
                echo "${item}," >> "$tmpJson"
            else
                echo "${item}" >> "$tmpJson"
            fi
            x=$((x+1))
        done
        echo "]" >> "$tmpJson"
    fi

    # Now insert the data into the database
    if [[ -z "${tmp_Table}" ]]; then
        if [[ -z "${tmp_ObjectName}" ]]; then
            tmpTable="tmpTable"
        else
            tmpTable="${tmp_ObjectName}"
        fi
        if [[ "$logging" == "true" ]]; then
            log_info "tmpTable: $tmpTable"
        else
            echo "tmpTable: $tmpTable"
        fi
    else
        tmpTable="$tmp_Table"
        if [[ "$logging" == "true" ]]; then
            log_info "tmpTable: $tmpTable"
        else
            echo "tmpTable: $tmpTable"
        fi
    fi
    if [[ -z "${tmp_PK}" ]]; then
        sqlite-utils insert "$tmpDb" "$tmpTable" "$tmpJson" --alter --ignore
    else
        pks=""
        for i in "${tmp_PK[@]}"; do
            pks="--pk=$i $pks"
        done
        eval "sqlite-utils insert $tmpDb $tmpTable $tmpJson --alter --ignore $pks"
    fi
    rm "$tmpJson"


    # Now export the data to the csv file when finished all responses
    if [[ -z "${tmp_Append}" ]]; then
        sqlite-utils "$tmpDb" "select * from $tmpTable" --csv > "${csvFile}"
    else
        if [[ "${tmp_Append}" == "Done" ]]; then
            sqlite-utils "$tmpDb" "select * from $tmpTable" --csv > "${csvFile}"
        fi
    fi

    if [[ -z "$tmp_Db" ]]; then
        if ! [[ "${tmp_Append}" == "Append" ]]; then
            rm "$tmpDb"
        fi
    fi

}

