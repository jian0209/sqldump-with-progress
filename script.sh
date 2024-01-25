#! /bin/bash

########
# Help #
########
Help()
{
    echo "Description: This script will dump the database with progress bar."
    echo ""
    echo "🏮 Attention: This script will not dump the system data or any table, included databases:"
    echo "information_schema, performance_schema, mysql, sys, innodb, and tmp."
    echo ""
    echo "####################################"
    echo "# Pre-requisite: pv                #"
    echo "# Install: sudo apt-get install pv #"
    echo "####################################"
    echo ""
    echo "Syntax: $0 [-h|-H|-P|--output|--databases|--no-data|...] < password.txt"
    echo "Syntax: $0 [-h|-H|-P|--output|--databases|--no-data|...]"
    echo "Usage: $0 -H=\"localhost\" -P=\"3306\" --output=\"/tmp/output.sql.gz\" --databases=\"database1 database2\" --no-data < password.txt"
    echo ""
    echo "options:"
    echo "-h --help           Print this Help."
    echo "-H --host           Hostname or IP address of the database server.[Default: localhost]"
    echo "-u --user           Username of the database server.[Default: root]"
    echo "-P --port           Port number of the database server.[Default: 3306]"
    echo "--output            Output file path, will using gzip to store the file with .gz extension, recommended extension: '.sql'.[Default: Output to /tmp/output.sql.gz]"
    echo "--where             Dump only rows selected by given WHERE condition. [Default: Dump all rows]"
    echo "--databases         Dump several databases. Give the database names separated by space. [Default: Dump all databases]"
    echo "--decryption        Decrypt the input file using base64. [Default: No]"
    echo "--no-data           Do not dump table contents. [Default: No]"
    echo "--skip-lock-tables  Do not lock tables for backup. [Default: No]"
}

#################
# Configuration #
#################

user="root"
password=""
databases=""
host="localhost"
port="3306"
output_file=""
where=""
decryption=false
no_data=false
has_database=false

if [ "$#" -eq 0 ]; then
    Help
    exit 0
fi

(
    set -e
    for arg in "$@"
    do
        case $arg in
            -h|--help)
                Help
                exit 0
            ;;
            -H=*|--host=*)
                host="${arg#*=}"
            ;;
            -u=*|--user=*)
                user="${arg#*=}"
            ;;
            -P=*|--port=*)
                port="${arg#*=}"
            ;;
            --output=*)
                output_file="${arg#*=}"
            ;;
            --where=*)
                where="${arg#*=}"
                has_database=true
            ;;
            --databases=*)
                databases="${arg#*=}"
                has_database=true
            ;;
            --decryption)
                decryption=true
            ;;
            --no-data)
                no_data=true
            ;;
            --skip-lock-tables)
                skip_lock_tables=true
            ;;
            *)
            ;;
        esac
    done
    
    echo "Read Configurations"
    if [ -t 0 ]; then
        echo "Enter password: " && read -s -r password
        decryption=false
    else
        read -r password
    fi
    
    if [ "$decryption" = true ]; then
        password=$(echo $password | base64 -d)
    fi
    
    # execute_dump_command="mysqldump -h$host -u$user -p$password -P$port --skip-lock-tables"
    execute_dump_command="mysqldump -h$host -u$user -p$password -P$port"
    database_list=$(mysql -h$host -u$user -p$password -e "SHOW DATABASES;" | tail -n +2 | grep -v -E '(information_schema|performance_schema|mysql|sys|innodb|tmp)')
    database_list=$(echo $database_list | tr '\n' ' ')
    
    if [ ${PIPESTATUS[0]} -ne 0 ]; then
        echo "Fatal: Your sql server is not running or your password is incorrect."
        exit 1
    fi
    
    if [ "$has_database" = false ]; then
        execute_get_size_command=$(mysql -h$host -u$user -p$password -e "SELECT ROUND(SUM(data_length + index_length) / 1024 / 1024, 2) AS 'Size (MB)' FROM information_schema.TABLES GROUP BY table_schema;" | tail -n +2 | grep -v -E '(information_schema|performance_schema|mysql|sys|innodb|tmp)' | awk '{s+=$1} END {print s}')
    fi
    
    if [ "$no_data" = true ]; then
        execute_dump_command="$execute_dump_command --no-data"
    fi

    if [ "$skip_lock_tables" = true ]; then
        execute_dump_command="$execute_dump_command --skip-lock-tables"
    fi
    
    if [ "$where" != "" ]; then
        databases_length=$(echo $databases | wc -w)
        if [ "$databases_length" -ne 1 ]; then
            echo "🏮 Attention: You can not use --where option with multiple databases option or no specific database."
            echo "   Please try with only one database."
            exit 1
        fi
        execute_dump_command="$execute_dump_command --where=\"$where\""
    fi
    
    if [ "$databases" != "" ]; then
        execute_dump_command="$execute_dump_command --databases $databases"
        databases=$(echo $databases | sed 's/ /","/g' | sed 's/^/"/' | sed 's/$/"/')
        execute_get_size_command=$(mysql -h$host -u$user -p$password -e "SELECT ROUND(SUM(data_length + index_length) / 1024 / 1024, 2) AS 'Size (MB)' FROM information_schema.TABLES WHERE table_schema IN ($databases) GROUP BY table_schema;" | tail -n +2 | grep -v -E '(information_schema|performance_schema|mysql|sys|innodb|tmp)' | awk '{s+=$1} END {print s}')
    fi
    
    if [ "$has_database" = false ]; then
        execute_dump_command="$execute_dump_command ""--databases"" $database_list"
    fi
    
    file_size=$(echo "$execute_get_size_command * 0.9" | bc -l | awk '{printf("%d\n",$1 + 0.5)}')

    if [ "$output_file" != "" ]; then
        execute_dump_command="$execute_dump_command | pv -W -s $file_size""M | gzip -c > $output_file"
    else
        execute_dump_command="$execute_dump_command | pv -W -s $file_size""M | gzip -c > /tmp/output.sql.gz"
    fi

    echo "Done Configuration"

    ################
    # Main Program #
    ################
    echo "Start Dumping"
    echo "Total File Size Around: $file_size""M"
    eval $execute_dump_command
    echo "Done Dumping"
) || exit 1
