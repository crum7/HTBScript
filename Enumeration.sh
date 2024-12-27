#!/bin/bash

# 引数処理
while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        --ip)
        IP="$2"
        shift
        shift
        ;;
        --name)
        machine_name="$2"
        shift
        shift
        ;;
        *)
        echo "Unknown argument: $1"
        exit 1
        ;;
    esac
done

# 必須引数の確認
if [ -z "$IP" ] || [ -z "$machine_name" ]; then
    echo "Usage: $0 --ip <IP> --name <machine_name>"
    exit 1
fi

# ドメイン設定
domain="http://$machine_name.htb"

# /etc/hostsに追加
echo "Adding $IP $machine_name.htb to /etc/hosts"
sudo sh -c "echo '$IP $machine_name.htb' >> /etc/hosts"

# mate-terminal を使って複数タブでコマンドを実行 (nmap, whatweb, 条件分岐を修正)
mate-terminal \
    --tab --title="Nmap,Whatweb " -- bash -c "sudo nmap -vvv -sCV -T4 -p0-65535 --reason $IP; echo 'Running whatweb...'; sleep 3; sudo whatweb http://$IP; exec bash" \
    --tab --title="HTTP Tasks" -- bash -c "echo 'Waiting for port 80/tcp to be discovered...'; sudo nmap -vvv -sCV -T4 -p80 --reason $IP | while read -r line; do if [[ \$line == *'Discovered open port 80/tcp'* ]]; then echo 'Port 80 detected. Running HTTP-specific tasks...'; feroxbuster -u http://$machine_name.htb; sudo dirsearch --url=http://$machine_name.htb --wordlist=/usr/share/seclists/Discovery/Web-Content/raft-medium-directories.txt --threads 30 --random-agent --format=simple; ffuf -w /usr/share/wordlists/seclists/Discovery/DNS/bitquark-subdomains-top100000.txt -u http://$machine_name.htb -H 'Host: FUZZ.$domain' -mc 200; break; fi; done; exec bash" \
    --tab --title="HTTPS Tasks" -- bash -c "echo 'Waiting for port 443/tcp to be discovered...'; sudo nmap -vvv -sCV -T4 -p443 --reason $IP | while read -r line; do if [[ \$line == *'Discovered open port 443/tcp'* ]]; then echo 'Port 443 detected. Running HTTPS-specific tasks...'; domain='https://$machine_name.htb'; feroxbuster -u $domain; sudo dirsearch --url=$domain --wordlist=/usr/share/seclists/Discovery/Web-Content/raft-medium-directories.txt --threads 30 --random-agent --format=simple; ffuf -w /usr/share/wordlists/seclists/Discovery/DNS/bitquark-subdomains-top100000.txt -u $domain -H 'Host: FUZZ.$domain' -mc 200; break; fi; done; exec bash"