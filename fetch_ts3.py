import socket
import json
import os

def get_ts3_data():
    # Deine TS3 Verbindungsdaten
    host = "51.38.106.208"
    port = 10087
    sid = 730
    user = "GrazyWeb"
    pw = "WZRvdn7Z"

    try:
        # Verbindung aufbauen
        s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        s.settimeout(10)
        s.connect((host, port))
        
        # TS3 Query Protokoll bedienen
        s.recv(1024) # Willkommens-Banner abfangen
        s.sendall(f"login {user} {pw}\n".encode())
        s.recv(1024) # Login Bestätigung
        s.sendall(f"use sid={sid}\n".encode())
        s.recv(1024) # Server Auswahl Bestätigung
        
        # Server-Info abfragen
        s.sendall(b"serverinfo\n")
        data = ""
        while True:
            chunk = s.recv(4096).decode()
            data += chunk
            if "error id=0" in chunk: break
        
        s.sendall(b"quit\n")
        s.close()

        # Daten auslesen (Clients online)
        online = data.split("virtualserver_clientsonline=")[1].split(" ")[0]
        max_clients = data.split("virtualserver_maxclients=")[1].split(" ")[0]

        return {
            "status": "online",
            "clients": int(online),
            "max": int(max_clients),
            "last_update": os.popen('date +"%H:%M:%S"').read().strip()
        }
    except Exception as e:
        return {"status": "offline", "error": str(e)}

# Ergebnis in die status.json schreiben
result = get_ts3_data()
with open("status.json", "w") as f:
    json.dump(result, f, indent=2)

print(f"Update durchgeführt: {result}")
