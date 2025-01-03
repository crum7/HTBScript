#!/bin/bash

# 引数処理
while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        --ip)
            IP="$2"
            shift 2
            ;;
        --name)
            machine_name="$2"
            shift 2
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

domain="http://$machine_name.htb"

# /etc/hosts への登録（重複防止）
if ! grep -q "$IP $machine_name.htb" /etc/hosts; then
    echo "[*] Adding $IP $machine_name.htb to /etc/hosts"
    sudo sh -c "echo '$IP $machine_name.htb' >> /etc/hosts"
else
    echo "[*] $IP $machine_name.htb is already in /etc/hosts"
fi

mate-terminal \
  --full-screen \
  --window --title="Nmap,Whatweb" \
  -e "bash -c '
        echo \"[+] Starting Nmap/Whatweb immediately...\";
        sleep 0;
        echo \"[*] sudo nmap -vvv -sCV -T4 -p0-65535 --reason $IP\";
        sudo nmap -vvv -sCV -T4 -p0-65535 --reason $IP;

        echo;
        echo \"[*] whatweb $domain\";
        sudo whatweb $domain;

        echo;
        echo \"[+] Completed Nmap/Whatweb. Press Enter to keep this tab open.\";
        read;
        exec bash
      '" \
  --tab --title="Feroxbuster" \
  -e "bash -c '
        echo \"[+] Delaying Feroxbuster start by 60 seconds...\";
        sleep 60;
        echo \"[*] feroxbuster -u $domain\";
        feroxbuster -u $domain;

        echo;
        echo \"[+] Completed feroxbuster. Press Enter to keep this tab open.\";
        read;
        exec bash
      '" \
  --tab --title="Dirsearch" \
  -e "bash -c '
        echo \"[+] Delaying Dirsearch start by 70 seconds...\";
        sleep 70;
        echo \"[*] sudo dirsearch --url=$domain \";
        sudo apt install dirsearch;
        sudo dirsearch --url=$domain \
                       --wordlist=/usr/share/seclists/Discovery/Web-Content/raft-medium-directories.txt \
                       --threads 30 \
                       --random-agent \
                       --format=simple;

        echo;
        echo \"[*] sudo dirsearch -u $domain -t 50 -i 200\";
        sudo dirsearch -u $domain -t 50 -i 200;

        echo;
        echo \"[+] Completed dirsearch. Press Enter to keep this tab open.\";
        read;
        exec bash
      '" \
  --tab --title="FFUF" \
  -e "bash -c '
        echo \"[+] Delaying FFUF start by 80 seconds...\";
        sleep 80;
        echo \"[*] ffuf -w /usr/share/wordlists/seclists/Discovery/DNS/bitquark-subdomains-top100000.txt -u http://$machine_name.htb -H \\\"Host: FUZZ.$machine_name.htb\\\" -mc 200\";
        ffuf -w /usr/share/wordlists/seclists/Discovery/DNS/bitquark-subdomains-top100000.txt \
             -u http://$machine_name.htb \
             -H \"Host: FUZZ.$machine_name.htb\" \
             -mc 200;

        echo;
        echo \"[+] Completed FFUF. Press Enter to keep this tab open.\";
        read;
        exec bash
      '"

echo "[*] Script completed."
