#!/bin/bash

psql_host="localhost"
psql_port=5432
db_name="host_agent"
psql_user="postgres"
psql_password="password"

if [ "$#" -ne 5 ]; then
    echo "Illegal number of parameters"
    exit 1
fi

# Save machine statistics in MB and current machine hostname to variables
vmstat_mb=$(vmstat --unit M)
hostname=$(hostname -f)

# Retrieve hardware specification variables
# xargs is a trick to trim leading and trailing white spaces
memory_free=$(echo "$vmstat_mb" | awk '{print $4}' | tail -n1 | tr -d 'M' | xargs)
cpu_idle=$(echo "$vmstat_mb" | awk '{print $15}' | tail -n1 | xargs)
cpu_kernel=$(echo "$vmstat_mb" | awk '{print $14}' | tail -n1 | xargs)
disk_io=$(vmstat -d | awk '{print $10}' | tail -n1 | xargs)
disk_available=$(df -BM / | awk 'NR==2{print $4}' | tr -d 'M' | xargs)


# Current time in `2019-11-26 14:40:19` UTC format
timestamp=$(date -u +"%Y-%m-%d %H:%M:%S")

# Subquery to find matching id in host_info table
host_id=$(psql -h $psql_host -p $psql_port -U $psql_user -d $db_name -t -c "SELECT id FROM host_info WHERE hostname='$hostname'")

# PSQL command: Inserts server hardware data into host_info table
insert_stmt="INSERT INTO host_usage (timestamp, host_id, memory_free, cpu_idle, cpu_kernel, disk_io, disk_available) VALUES ('$timestamp', $host_id, $memory_free, $cpu_idle, $cpu_kernel, $disk_io, $disk_available)"


# Set the PGPASSWORD environment variable for psql
export PGPASSWORD=$psql_password

# Execute the INSERT statement using psql
psql -h $psql_host -p $psql_port -d $db_name -U $psql_user -c "$insert_stmt"

# Check if the INSERT operation was successful
if [ $? -eq 0 ]; then
    echo "Data inserted successfully."
else
    echo "Error: Data insertion failed."
fi



# Exit with the appropriate status code
exit $?
