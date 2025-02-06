from flask import Flask, render_template, jsonify, request, abort, send_file
from datetime import datetime
from functions import (
    count_dnsmasq,
    generation_monitor_temple,
    load_iplist,
    update_installing_status,
    update_info,
    update_diskstate,
    update_gpustate,
    update_ibstate,
    update_finished_status,
    update_finished_ip,
    parse_config,
    get_len_iprange,
)
import os
import psutil
import time
import re

app = Flask(__name__)

# time
app.config["isGetStartTime"] = False
app.config["startTime"] = None
app.config["endTime"] = 0
app.config["installTime"] = 0
app.config["isFinished"] = False
app.config["finishedCount"] = 0

# counts of sent files
app.config["count_initrd"] = 0
app.config["count_vmlinuz"] = 0
app.config["count_iso"] = 0
app.config["count_userdata"] = 0
app.config["count_preseed"] = 0
app.config["count_install"] = 0


iplist_path = "/workspace/iplist.txt"
dnsmasq_log_path = "/workspace/log/dnsmasq.log"
config_yaml_path = "/workspace/config.yaml"

# generation monitor.txt temple and Count the total number of machines in the iplist.txt
app.config["monitor_data"] = generation_monitor_temple(iplist_path)
app.config["iplist"] = load_iplist(iplist_path)

current_year = datetime.now().year

# Network Speed DHCP config.yaml
config_data = parse_config(config_yaml_path)

interface = config_data["manager_nic"]
dhcp_s = config_data["dhcp_s"]
dhcp_e = config_data["dhcp_e"]
manger_ip = config_data["manager_ip"]
compute_storage = config_data["compute_storage"]
nexus_passwd = config_data["nexus_passwd"]
iso = config_data["iso"]

total_ips = get_len_iprange(dhcp_s, dhcp_e)


@app.route("/updateusedip")
def updateusedip():
    try:
        with open("/var/lib/misc/dnsmasq.leases", "r") as file:
            lines = file.readlines()
        return jsonify({"usedip": len(lines)})
    except FileNotFoundError:
        print("Error: The file /var/lib/misc/dnsmasq.leases does not exist.")
        return jsonify({"usedip": 0}), 404
    except Exception as e:
        print(f"An error occurred while reading the file: {e}")
        return jsonify({"usedip": 0}), 500


@app.route("/<path:filepath>")
def download_file(filepath):
    BASE_DIR = "/"
    file_path = os.path.join(BASE_DIR, filepath)
    if os.path.isfile(file_path):
        if "initrd" in file_path:
            app.config["count_initrd"] += 1
        elif "vmlinuz" in file_path:
            app.config["count_vmlinuz"] += 1
        elif iso in file_path:
            app.config["count_iso"] += 1
        elif file_path == "/user-data/user-data" or file_path == "/kickstart/kickstart.cfg":
            app.config["count_userdata"] += 1
        elif file_path == "/user-data/preseed.sh":
            app.config["count_preseed"] += 1
        elif file_path == "/user-data/install.sh":
            app.config["count_install"] += 1

        return send_file(file_path, as_attachment=True)

    else:
        abort(404, description="File not found")


@app.route("/speed")
def get_speed():
    net_io = psutil.net_io_counters(pernic=True)
    if interface in net_io:
        rx_old = net_io[interface].bytes_recv
        tx_old = net_io[interface].bytes_sent
        time.sleep(1)
        net_io = psutil.net_io_counters(pernic=True)
        rx_new = net_io[interface].bytes_recv
        tx_new = net_io[interface].bytes_sent
        rx_speed = (rx_new - rx_old) / 1024 / 1024
        tx_speed = (tx_new - tx_old) / 1024 / 1024
        return jsonify({"rx_speed": rx_speed, "tx_speed": tx_speed})
    return jsonify({"rx_speed": 0, "tx_speed": 0})


# Install time
@app.route("/time")
def get_time():

    if not app.config["isGetStartTime"]:
        if os.path.exists(dnsmasq_log_path):
            with open(dnsmasq_log_path, "r") as file:
                for line in file:
                    if "/tftp/ipxe.cfg" in line:
                        time_regex = r"(\w{3}\s+\d{1,2}\s+\d{2}:\d{2}:\d{2})"
                        matched = re.search(time_regex, line)
                        time_str = matched.group(1)
                        log_time = datetime.strptime(
                            f"{time_str} {current_year}", "%b %d %H:%M:%S %Y"
                        )
                        app.config["startTime"] = log_time
                        app.config["isGetStartTime"] = True
                        break

    if app.config["isGetStartTime"]:
        if app.config["finishedCount"] != (
            len(app.config["monitor_data"]) - 1
        ):
            app.config["installTime"] = (
                datetime.now().replace(microsecond=0) - app.config["startTime"]
            )
        else:
            app.config["installTime"] = app.config["endTime"] - app.config["startTime"]    

    if app.config["installTime"] == 0:
        return jsonify({"installTime": 0})
    seconds = int(app.config["installTime"].total_seconds())
    return jsonify({"installTime": seconds})


# favicon.ico
@app.route("/favicon.ico")
def favicon():
    return "", 204


# curl -X POST -d "serial=$SN" http://${SERVER_IP}:5000/receive_serial_s
@app.route("/receive_serial_s", methods=["POST"])
def receive_serial_s():
    serial_number = request.form.get("serial")
    client_ip = request.remote_addr
    if serial_number:
        found, updated_monitor_data = update_installing_status(
            app.config["monitor_data"], serial_number, client_ip
        )
        if found:
            app.config["monitor_data"] = updated_monitor_data
        return "", 204
    else:
        return "", 400


def find_by_serial(serial):
    if app.config["iplist"] is None:
        return {"error": "iplist.txt file not found"}
    for entry in app.config["iplist"]:
        if entry["serial"] == serial:
            return entry
    return None


# curl -X POST -d "serial=$SN" "http://${SERVER_IP}:5000/request_iplist"
@app.route("/request_iplist", methods=["POST"])
def request_iplist():
    serial = request.form.get("serial")
    if not serial:
        return "", 400

    entry = find_by_serial(serial)
    if entry:
        if "error" in entry:
            return "", 404
        else:
            return jsonify(entry)
    else:
        return "", 404


# curl -X POST -d "serial=$SN&diskstate=none|ok|nomatch" "http://${SERVER_IP}:5000/diskstate"
@app.route("/diskstate", methods=["POST"])
def diskstate():
    serial_number = request.form.get("serial")
    diskstate = request.form.get("diskstate")
    if serial_number and diskstate:
        found, updated_monitor_data = update_diskstate(
            app.config["monitor_data"], serial_number, diskstate
        )
        if found:
            app.config["monitor_data"] = updated_monitor_data
        return "", 204
    else:
        return "", 400


# curl -X POST -d "serial=$SN&ibstate=ok" "http://${SERVER_IP}:5000/ibstate"
@app.route("/ibstate", methods=["POST"])
def ibstate():
    serial_number = request.form.get("serial")
    ibstate = request.form.get("ibstate")
    if serial_number and ibstate:
        found, updated_monitor_data = update_ibstate(
            app.config["monitor_data"], serial_number, ibstate
        )
        if found:
            app.config["monitor_data"] = updated_monitor_data
        return "", 204
    else:
        return "", 400


# curl -X POST -d "serial=$SN&gpustate=ok" "http://${SERVER_IP}:5000/gpustate"
@app.route("/gpustate", methods=["POST"])
def gpustate():
    serial_number = request.form.get("serial")
    gpustate = request.form.get("gpustate")
    if serial_number and gpustate:
        found, updated_monitor_data = update_gpustate(
            app.config["monitor_data"], serial_number, gpustate
        )
        if found:
            app.config["monitor_data"] = updated_monitor_data
        return "", 204
    else:
        return "", 400


# curl -X POST -d "serial=$SN&info=$info_name&lsblk=$lsblk_output&ipa=$ipa_output" "http://${SERVER_IP}:5000/updateinfo"
@app.route("/updateinfo", methods=["POST"])
def updateinfo():
    serial_number = request.form.get("serial")
    infoname = request.form.get("info")
    lsblk_output = request.form.get("lsblk")
    ipa_output = request.form.get("ipa")
    if serial_number and infoname:
        found, updated_monitor_data = update_info(
            app.config["monitor_data"], serial_number, infoname
        )
        if found:
            app.config["monitor_data"] = updated_monitor_data
            
        with open(f"/workspace/log/{infoname}", "a") as log_file:
            current_time = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
            log_file.write(current_time + "\n")
            log_file.write("---------------info-----------------" + "\n" + "\n")
            if lsblk_output:
                log_file.write("--------lsblk--------" + "\n")
                log_file.write(lsblk_output + "\n" + "\n")
            if ipa_output:
                log_file.write("--------ip a--------" + "\n")
                log_file.write(ipa_output + "\n" + "\n")
            log_file.write("---------------info-end---------------" + "\n" + "\n")
        return "", 204
    else:
        return "", 400


# curl -X POST -d "serial=$SN" http://${SERVER_IP}:5000/receive_serial_ip
@app.route("/receive_serial_ip", methods=["POST"])
def receive_serial_ip():
    serial_number = request.form.get("serial")
    client_ip = request.remote_addr
    if serial_number:
        updated_monitor_data = update_finished_ip(
            app.config["monitor_data"], serial_number, client_ip
        )
        app.config["monitor_data"] = updated_monitor_data
        return "", 204
    else:
        return "", 400


# curl -X POST -d "serial=$SN" http://${SERVER_IP}:5000/receive_serial_e
@app.route("/receive_serial_e", methods=["POST"])
def receive_serial_e():

    if not app.config["isGetStartTime"]:
        if os.path.exists(dnsmasq_log_path):
            with open(dnsmasq_log_path, "r") as file:
                for line in file:
                    if "tftp/ipxe.cfg" in line:
                        time_regex = r"(\w{3}\s+\d{1,2}\s+\d{2}:\d{2}:\d{2})"
                        matched = re.search(time_regex, line)
                        time_str = matched.group(1)
                        log_time = datetime.strptime(
                            f"{time_str} {current_year}", "%b %d %H:%M:%S %Y"
                        )
                        app.config["startTime"] = log_time
                        app.config["isGetStartTime"] = True
                        break

    app.config["finishedCount"] = app.config["finishedCount"] + 1

    if app.config["finishedCount"] == (len(app.config["monitor_data"]) - 1):
        app.config["endTime"] = datetime.now().replace(microsecond=0)

    
    serial_number = request.form.get("serial")

    if serial_number:
        found, updated_monitor_data = update_finished_status(
            app.config["monitor_data"],
            serial_number,
        )
        if found:
            app.config["monitor_data"] = updated_monitor_data

        return "", 204
    else:
        return "", 400


# READ logs
@app.route("/logs/<path:file_path>")
def open_file(file_path):
    try:
        with open("/workspace/log/" + file_path, "r") as f:
            file_content = f.read()
        return render_template(
            "file.html", file_path=file_path, file_content=file_content
        )
    except FileNotFoundError:
        abort(404, description="no log generation")


@app.route("/refresh_count")
def refresh_data():
    cnt_start_tag = count_dnsmasq(dnsmasq_log_path)

    cnt_end_tag = app.config["finishedCount"]

    data = {
        "cnt_start_tag": cnt_start_tag,
        "cnt_Initrd": app.config["count_initrd"],
        "cnt_vmlinuz": app.config["count_vmlinuz"],
        "cnt_ISO": app.config["count_iso"],
        "cnt_userdata": app.config["count_userdata"],
        "cnt_preseed": app.config["count_preseed"],
        "cnt_install": app.config["count_install"],
        "cnt_end_tag": cnt_end_tag,
    }
    return jsonify(data)


@app.route("/get_state_table")
def get_state_table():
    headers = app.config["monitor_data"][0]
    data = [dict(zip(headers, row)) for row in app.config["monitor_data"][1:]]
    table_content = render_template("state.html", data=data)
    return table_content


@app.route("/")
def index():
    return render_template("monitor.html", interface=interface, total_ips=total_ips)


if __name__ == "__main__":
    app.run("0.0.0.0", 5000)
