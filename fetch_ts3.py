import socket
import json
import os

def get_ts3_data():
    host = "51.38.106.208"
    port = 10087
    sid = 730
    user = ""
    pw = ""

    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        s.settimeout(10)
        s.connect((host, port))
        s.recv(1024)
        s.sendall(f"login {user} {pw}\n".encode())
        s.recv(1024)
        s.sendall(f"use sid={sid}\n".encode())
        s.recv(1024)
        
        # Kanäle und Clients abrufen
        s.sendall(b"channellist\n")
        chan_data = ""
        while True:
            chunk = s.recv(4096).decode()
            chan_data += chunk
            if "error id=0" in chunk: break
            
        s.sendall(b"clientlist\n")
        client_data = ""
        while True:
            chunk = s.recv(4096).decode()
            client_data += chunk
            if "error id=0" in chunk: break

        s.sendall(b"quit\n")
        s.close()

        # Kanäle parsen
        channels = []
        for c in chan_data.split('|'):
            if "cid=" in c:
                cid = c.split("cid=")[1].split(" ")[0]
                name = c.split("channel_name=")[1].split(" ")[0].replace("\\s", " ")
                channels.append({"id": cid, "name": name, "users": []})

        # User zuordnen
        online_count = 0
        for cl in client_data.split('|'):
            if "client_type=0" in cl:
                name = cl.split("client_nickname=")[1].split(" ")[0].replace("\\s", " ")
                cid = cl.split("cid=")[1].split(" ")[0]
                online_count += 1
                for chan in channels:
                    if chan["id"] == cid:
                        chan["users"].append(name)

        return {
            "status": "online",
            "clients": online_count,
            "max": 26, # Dein Limit
            "channels": channels,
            "updated_at": os.popen('date +"%H:%M"').read().strip()
        }
    except Exception as e:
        return {"status": "offline", "error": str(e)}

result = get_ts3_data()
with open("status.json", "w") as f:
    json.dump(result, f, indent=2)
