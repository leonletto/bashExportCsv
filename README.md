# bashExportCsv
Bash function to export flattened csv files from curl responses or other json.

## Why is this needed?
If you have large json that you want to flatten for exporting to csv for visualization in Spreadsheets
or importing into databases, the modules available lack the multi-level functionality available in jq for 
flattening json objects and arrays which I prefer.   However, if you try to do the export using jq, the speed 
suffers immensely and I could only get to 20-30 lines per second to export json with 500 byte records.  This is 
unusable for large responses from enterprise REST API's.  For example, a large company might have tens of 
thousands of devices under management in their MDM system so getting a spreadsheet out of a REST query would 
be very slow.  However jq is very fast a flattening the same json and dumping it to a file.  I found that 
sqlite-utils was the fastest way to export the flattened json to csv by using a temporary database as an
intermediary.  This script will flatten the json using jq, then export it to a temporary sqlite database
using sqlite-utils and export the resulting database to csv using sqlite-utils.  

The speed is about 30x faster than using bash or jq alone since almost everything is done in c.  For example,
exporting 40,000 records using jq and bash takes about 20 minutes vs 30 seconds using this script.

I try to hide all of the complexity of the script from the user so that it is easy to use.  The script has some 
requirements though.  The script requires jq, and sqlite-utils.  

## Requirements
* jq
* * jq is available in most package managers or can be downloaded from https://stedolan.github.io/jq/download/ 
* sqlite-utils
* * sqlite-utils is available in most package managers or can be downloaded from https://sqlite-utils.datasette.io/en/stable/
* bashLogger
* * bashLogger is optional and available at https://github.com/leonletto/bashLogger.git and can be installed as a submodule as shown below

If you add it using the following code it will ba automatically picked up and used for logging.
```bash
git submodule add https://github.com/leonletto/bashLogger.git submodules/bashLogger

```

## Usage
```bash
# Import the function
. ./export_csv.sh

# Call the function
export_csv "$(curl -s https://jsonplaceholder.typicode.com/todos)" "todos.csv"

```