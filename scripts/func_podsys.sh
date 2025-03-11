# delete_logs of dnsmasq(docker)
delete_logs() {
    if [ ! -d "workspace/log" ]; then
        mkdir -p "workspace/log"
    fi
    logs=("workspace/log/dnsmasq.log")

    for log in "${logs[@]}"; do
        if [ -f "$log" ]; then
            rm "$log"
        fi
    done
}

# Function to check the iplist.txt format
check_iplist_format() {
    file_path="$1"
    # Check if the file exists
    if [ ! -f "$file_path" ]; then
        echo "Warning: File $file_path does not exist."
        return 1
    fi
    while IFS= read -r line; do
        fields=($line) # Split the line into fields
        # Check if the number of fields is 5
        if [ ${#fields[@]} -ne 5 ]; then
            echo "Incorrect format on line iplist.txt: $line"
            continue
        fi
        # Check if the 3rd column is a valid IP address with subnet mask
        if ! echo "${fields[2]}" | grep -qE '^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}(/[0-9]{1,2})?$'; then
            echo "Invalid IP address with subnet mask in the 3rd column on line of iplist.txt: $line"
            continue
        fi

        # Check if the DNS column is a valid IP address
        if [ "${fields[4]}" != "none" ] && ! echo "${fields[4]}" | grep -qE '^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}(/[0-9]{1,2})?$'; then
            echo "Invalid DNS in the 4th column on line of iplist.txt: $line"
            continue
        fi
    done <"$file_path"
}
