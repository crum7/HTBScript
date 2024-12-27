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

# nmapスキャン
nmap_info=$(sudo nmap -vvv -sCV -T4 -p0-65535 -Pn --reason $IP)
echo "Nmap scan completed:"
echo "$nmap_info"

# タブを開いてコマンドを実行（mate-terminal）
mate-terminal --title="Nmap" -- bash -c "echo 'Running nmap...'; sudo nmap -vvv -sCV -T4 -p0-65535 -Pn --reason $IP; exec bash" &
mate-terminal --title="Feroxbuster" -- bash -c "echo 'Running feroxbuster...'; feroxbuster -u $domain; exec bash" &
mate-terminal --title="Dirsearch" -- bash -c "echo 'Running dirsearch...'; sudo dirsearch --url=$domain --wordlist=/usr/share/seclists/Discovery/Web-Content/raft-medium-directories.txt --threads 30 --random-agent --format=simple; exec bash" &
mate-terminal --title="FFUF" -- bash -c "echo 'Running ffuf...'; ffuf -w /usr/share/wordlists/seclists/Discovery/DNS/bitquark-subdomains-top100000.txt -u $domain -H 'Host: FUZZ.$domain' -mc 200; exec bash" &

# HTTP/HTTPSに応じた条件分岐
if echo "$nmap_info" | grep -q "80/tcp open"; then
    echo "Port 80 detected. Running HTTP-specific tasks..."
    feroxbuster_info=$(feroxbuster -u $domain)
    echo "Feroxbuster output:"
    echo "$feroxbuster_info"

    sudo apt install dirsearch -y
    dirbuster_simple_info=$(sudo dirsearch -u $domain -t 50 -i 200)
    echo "Dirsearch (simple) output:"
    echo "$dirbuster_simple_info"
    
    dirbuster_complicated_info=$(sudo dirsearch --url=$domain --wordlist=/usr/share/seclists/Discovery/Web-Content/raft-medium-directories.txt --threads 30 --random-agent --format=simple)
    echo "Dirsearch (complicated) output:"
    echo "$dirbuster_complicated_info"

    ffuf_info=$(ffuf -w /usr/share/wordlists/seclists/Discovery/DNS/bitquark-subdomains-top100000.txt -u $domain -H "Host: FUZZ.$domain" -mc 200)
    echo "FFUF output:"
    echo "$ffuf_info"

elif echo "$nmap_info" | grep -q "443/tcp open"; then
    echo "Port 443 detected. Running HTTPS-specific tasks..."
    domain="https://$machine_name.htb"

    feroxbuster_info=$(feroxbuster -u $domain)
    echo "Feroxbuster output:"
    echo "$feroxbuster_info"

    sudo apt install dirsearch -y
    dirbuster_simple_info=$(sudo dirsearch -u $domain -t 50 -i 200)
    echo "Dirsearch (simple) output:"
    echo "$dirbuster_simple_info"
    
    dirbuster_complicated_info=$(sudo dirsearch --url=$domain --wordlist=/usr/share/seclists/Discovery/Web-Content/raft-medium-directories.txt --threads 30 --random-agent --format=simple)
    echo "Dirsearch (complicated) output:"
    echo "$dirbuster_complicated_info"

    ffuf_info=$(ffuf -w /usr/share/wordlists/seclists/Discovery/DNS/bitquark-subdomains-top100000.txt -u $domain -H "Host: FUZZ.$domain" -mc 200)
    echo "FFUF output:"
    echo "$ffuf_info"
else
    echo "No HTTP/HTTPS ports detected. Exiting."
fi
