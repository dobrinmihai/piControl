import eventlet
eventlet.monkey_patch()  

from flask import Flask, jsonify, request
from flask_socketio import SocketIO, emit
import paramiko
import threading
import subprocess

app = Flask(__name__)
socketio = SocketIO(app, cors_allowed_origins="*")

clients = {}

IP_RANGE = "192.168.0.1/24"  #  modifică dacă ai altă rețea

def get_ip_mac_nmap():
    try:
        output = subprocess.check_output(["nmap", "-sn", IP_RANGE], universal_newlines=True)
        devices = []
        current_ip = None

        for line in output.splitlines():
            if "Nmap scan report for" in line:
                current_ip = line.split()[-1]
            elif "MAC Address" in line and current_ip:
                mac = line.split()[2]
                devices.append({
                    "ip": current_ip,
                    "mac": mac
                })
                current_ip = None

        return devices
    except Exception as e:
        return [{"error": str(e)}]

@app.route('/scan', methods=['GET'])
def scan_network():
    devices = get_ip_mac_nmap()
    return jsonify(devices)

@socketio.on('connect')
def handle_connect():
    print('Client connected')

@socketio.on('start_ssh')
def start_ssh(data):
    sid = request.sid
    hostname = data.get('hostname')
    username = data.get('username')
    password = data.get('password')

    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())

    try:
        ssh.connect(hostname, username=username, password=password)
        chan = ssh.invoke_shell()
        clients[sid] = chan
        def read_from_ssh():
            try:
                while True:
                    data = chan.recv(1024)
                    if not data:
                        break
                    socketio.emit('ssh_data', data.decode('utf-8'), to=sid)
            except Exception as e:
                print(f"SSH read error: {e}")

        thread = threading.Thread(target=read_from_ssh)
        thread.start()

    except Exception as e:
        emit('ssh_error', str(e))

@socketio.on('input')
def handle_input(data):
    chan = clients.get(request.sid)
    if chan:
        chan.send(data)

@socketio.on('disconnect')
def handle_disconnect():
    chan = clients.pop(request.sid, None)
    if chan:
        chan.close()
    print('Client disconnected')

if __name__ == '__main__':
    socketio.run(app, host='0.0.0.0', port=3000, debug=True)
