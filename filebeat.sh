#!/bin/bash
#host_ip=`ip a | grep 172.31| awk '{print $2}' | cut -d/ -f1`
host_ip=`ip a s eth0 | grep -v "lo:0" | egrep -o "([0-9]{1,3}\.){3}[0-9]{1,3}" | grep -v 255 |  head -1`
hostname=`echo $HOSTNAME`
echo $host_ip
#ps -ef  | grep filebeat && exit
wget 172.31.100.39:8282/filebeat-7.10.1-linux-x86_64.tar.gz
tar -xf filebeat-7.10.1-linux-x86_64.tar.gz -C /usr/local/
cat > /usr/lib/systemd/system/filebeat.service  << EOF
[Unit]
Description=Filebeat
Documentation=https://www.elastic.co/products/beats/filebeat
Wants=network-online.target
After=network-online.target

[Service]
ExecStart=/usr/local/filebeat-7.10.1-linux-x86_64/filebeat -c /usr/local/filebeat-7.10.1-linux-x86_64/filebeat.yml
Restart=always
RestartSec=1
StartLimitIntervalSec=0

[Install]
WantedBy=multi-user.target
EOF

cat > /usr/local/filebeat-7.10.1-linux-x86_64/filebeat.yml << EOF
filebeat.inputs:
- type: log
  enabled: true
  paths:
    - /var/log/messages
    - /var/log/cron
    - /var/log/secure
  tail_files: true
  fields:
    log_topic: systemlog

processors:
  - add_fields:
      target: server
      fields:
        ip: $host_ip
        role: $hostname

output.kafka:
  enabled: true
  hosts: ["172.31.100.136:9092", "192.168.32.15:9092", "192.168.32.74:9092"]
  topic: '%{[fields.log_topic]}'
  version: 0.10.2.1
  partition.hash:
    reachable_only: true
  compression: gzip
  max_message_bytes: 1000000
  required_acks: 1
logging.to_files: true
EOF
systemctl daemon-reload
systemctl start filebeat && systemctl enable filebeat
echo "filebeat install success"
