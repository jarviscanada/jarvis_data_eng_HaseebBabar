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

# Collect host information
hostname=$(hostname -f | sed "s/'/''/g")  # Escape single quotes
cpu_number=$(lscpu | grep 'Socket(s):' | awk '{print $2}')
cpu_architecture=$(lscpu | grep 'Architecture:' | awk '{print $2}')
cpu_model=$(lscpu | grep 'Model name:' | awk -F':' '{print $2}' | xargs)
cpu_mhz=$(lscpu | grep 'CPU MHz:' | awk -F':' '{print $2}' | xargs)
l2_cache=$(lscpu | grep 'L2 cache:' | awk -F':' '{print $2}' | xargs | sed 's/[^0-9]*//g')  # Remove non-numeric characters
total_mem=$(free -m | grep 'Mem:' | awk '{print $2}')

# Current time in `2019-11-26 14:40:19` UTC format
timestamp=$(date -u +"%Y-%m-%d %H:%M:%S")

# PSQL command: Inserts host information into host_info table
insert_stmt="INSERT INTO host_info (hostname, cpu_number, cpu_architecture, cpu_model, cpu_mhz, l2_cache, \"timestamp\", total_mem) VALUES ('$hostname', $cpu_number, '$cpu_architecture', '$cpu_model', $cpu_mhz, '$l2_cache', '$timestamp', $total_mem)"


# Print the INSERT statement for debugging
echo "Debug: $insert_stmt"

# Set the PGPASSWORD environment variable for psql
export PGPASSWORD=$psql_password

# Execute the INSERT statement using psql
psql -h $psql_host -p $psql_port -d $db_name -U $psql_user -c "$insert_stmt"

# Subquery to find matching hostname in host_info table
existing_host=$(psql -h $psql_host -p $psql_port -U $psql_user -d $db_name -t -c "SELECT hostname FROM host_info WHERE hostname='$hostname'")

if [ -z "$existing_host" ]; then
    # The host does not exist, so insert a new record
    psql -h $psql_host -p $psql_port -d $db_name -U $psql_user -c "$insert_stmt"
    echo "Data inserted successfully."
else
    # The host already exists, you can choose to skip or update the record
    echo "Host already exists. Skipping insertion or performing an update."
fi


# Check if the INSERT operation was successful
if [ $? -eq 0 ]; then
    echo "Data inserted successfully."
else
    echo "Error: Data insertion failed."
fi

# Exit with the appropriate status code
exit $?

