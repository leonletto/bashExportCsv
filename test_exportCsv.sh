#!/usr/bin/env bash
set -o errexit
set -o nounset
set -o pipefail
if [[ "${TRACE-0}" == "1" ]]; then set -o xtrace; fi

. ./export_csv.sh

# 10 names in an array for testing
Names=( "Joe" "Frank" "Mary" "Dave" "Jasper" "Sarah" "Leon" "Jason" "Jeremy" "Elon" )
DevicePlatforms=( "Apple" "WinRt" "Android" "Apple" "Apple" "Apple" "WinRt" "WinRt" "WinRt" "WinRt" )
OnelevelDeepArray=( "One" "Two" "Three" "Four" "Five" "Six" "Seven" "Eight" "Nine" "Ten" )
TwolevelDeepArray=( "Violet" "Purple" "Blue" "Turquoise" "Green" "Yellow" "Pink" "Orange" "Red" "Brown" )


#Test1 - Pass an array of Named objects and a csv file name
# Named Array of 5 Devices with a deviceId, a device Name and a device Type
tempBashNamedArray=$(jq -n '{ "Devices": [], "Page": 0, "PageSize": 5, "Total": 5 }')
#Add 5 Devices to the array
for i in {0..4}; do
    tempBashNamedArray=$(echo "$tempBashNamedArray" | jq '.Devices += [{"deviceId": "'"$i"'", "deviceName": "'"${Names[$i]}'s Device"'", "deviceType": "'"${DevicePlatforms[$i]}"'"}]' )
done
export_csv "$tempBashNamedArray" "./TestExportCsv1.csv" "Devices"

#Test2 - Pass two arrays of Named objects ( paged responses ) and a csv file name and append to the csv file
tempBashNamedArray=$(jq -n '{ "Devices": [], "Page": 0, "PageSize": 5, "Total": 10 }')
#Add 5 Devices to the array
for i in {0..4}; do
    tempBashNamedArray=$(echo "$tempBashNamedArray" | jq '.Devices += [{"deviceId": "'"$i"'", "deviceName": "'"${Names[$i]}'s Device"'", "deviceType": "'"${DevicePlatforms[$i]}"'"}]' )
done
tempBashNamedArray2=$(jq -n '{ "Devices": [], "Page": 1, "PageSize": 5, "Total": 10 }')
#Add 5 Devices to the array
for i in {5..9}; do
    tempBashNamedArray2=$(echo "$tempBashNamedArray2" | jq '.Devices += [{"deviceId": "'"$i"'", "deviceName": "'"${Names[$i]}'s Device"'", "deviceType": "'"${DevicePlatforms[$i]}"'"}]' )
done
pk=("deviceId")
export_csv "$tempBashNamedArray" "./TestExportCsv2.csv" "Devices" "Append" "${pk[@]}"
export_csv "$tempBashNamedArray2" "./TestExportCsv2.csv" "Devices" "Done" "${pk[@]}"

#Test3 - Pass an array of objects and a csv file name
# Array of 5 Devices with a deviceId, a device Name and a device Type
tempBashArray=$(jq -n '[]')
for i in {0..4}; do
    tempBashArray=$(echo "$tempBashArray" | jq '. += [{"deviceId": "'"$i"'", "deviceName": "'"${Names[$i]}'s Device"'", "deviceType": "'"${DevicePlatforms[$i]}"'"}]' )
done
export_csv "$tempBashArray" "./TestExportCsv3.csv"

#Test4 - Pass an array of objects and a csv file name and a table name
#Generate a bash array of 5 Devices with a deviceId, a device Name and a device Type using jq and a bash for loop
tempBashArray=$(jq -n '[]')
for i in {0..4}; do
    tempBashArray=$(echo "$tempBashArray" | jq '. += [{"deviceId": "'"$i"'", "deviceName": "'"${Names[$i]}'s Device"'", "deviceType": "'"${DevicePlatforms[$i]}"'"}]' )
done
export_csv "$tempBashArray" "./TestExportCsv4.csv" "" "" "" "" "" "Devices"

#Test5 - Pass an array of objects with a duplicate and make sure they aren't added to the csv file
pk=("deviceId")
export_csv "$tempBashArray" "./TestExportCsv5.csv" "" "Append" "${pk[@]}"
tempBashArray=$(echo "$tempBashArray" | jq '. += [{"deviceId": "1", "deviceName": "Test_1TestDups", "deviceType": "Apple"}]' )
export_csv "$tempBashArray" "./TestExportCsv5.csv" "" "Done" "${pk[@]}"

#Test6 - Pass an array of objects with multiple levels of depth and make sure they are added to the csv file correctly
# The extra field, OnelevelDeepArray contains an array of objects or words which should be added to the csv file with _ appended to the field name between levels
# The third level contains an array of colors which should be added to the csv file with _ appended to the field name between levels

tempBashArray=$(jq -n '[]')
for i in {0..4}; do
    tempBashArray=$(echo "$tempBashArray" | jq '. += [{"deviceId": "'"$i"'", "deviceName": "'"${Names[$i]}'s Device"'", "deviceType": "'"${DevicePlatforms[$i]}"'", "OneLevelDeepArray": []}]' )
    for j in {0..1}; do
        tempBashArray=$(echo "$tempBashArray" | jq '.['"$i"'].OneLevelDeepArray += [{"TwoLevelDeepArray": "'"${OnelevelDeepArray[$j]}"'"}]' )
    done
    for j in {2..3}; do
        tempBashArray=$(echo "$tempBashArray" | jq '.['"$i"'].OneLevelDeepArray += [{"TwoLevelDeepArray": []}]' )
        for k in {0..1}; do
            tempBashArray=$(echo "$tempBashArray" | jq '.['"$i"'].OneLevelDeepArray['"$j"'].TwoLevelDeepArray += [{"ThreeLevelDeepArray": "'"${TwolevelDeepArray[$k]}"'"}]' )
        done
        for k in {2..3}; do
            tempBashArray=$(echo "$tempBashArray" | jq '.['"$i"'].OneLevelDeepArray['"$j"'].TwoLevelDeepArray += [{"ThreeLevelDeepArray": ["'"${TwolevelDeepArray[$k]}"'"]}]' )
        done
    done
done

echo "$tempBashArray" > ./TestExportCsv6.json

export_csv "$tempBashArray" "./TestExportCsv6.csv"