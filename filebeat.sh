IP=`ifconfig  | grep 172.31 |  awk '{print $2}'`
systemctl stop filebeat
rm -rf /usr/local/filebeat*
# 内网传输
wget 172.31.100.39:8282/filebeat-7.16.2-linux-x86_64.tar.gz
# 公网传输
# wget https://artifacts.elastic.co/downloads/beats/filebeat/filebeat-7.16.2-linux-x86_64.tar.gz
tar xf filebeat-7.16.2-linux-x86_64.tar.gz -C /usr/local/
cat > /usr/local/filebeat-7.16.2-linux-x86_64/filebeat.yml<< EOF
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

- type: log
  enabled: true
  encoding: utf-8
  exclude_files:
  - .*debug.log
  multiline:
    match: after
    negate: true
    pattern: ^[0-9]
  paths:
  - /data/logs/*/*.log
  - /data/logs/*/*/*.log
  - /data/logs/*/*/*/*.log
  scan_frequency: 10s
  tail_files: true
  fields:
    log_topic: docker

processors:
  - add_fields:
      target: server
      fields:
        ip: $IP
        role: $HOSTNAME

output.kafka:
  enabled: true
  hosts: ["192.168.32.165:9092", "192.168.32.149:9092", "192.168.32.91:9092"]
  topic: '%{[fields.log_topic]}'
  version: 0.10.2.1
  partition.hash:
    reachable_only: true
  compression: gzip
  max_message_bytes: 1000000
  required_acks: 1
logging.to_files: true

EOF


cat > /usr/lib/systemd/system/filebeat.service<< EOF
[Unit]
Description=Filebeat
Documentation=https://www.elastic.co/products/beats/filebeat
Wants=network-online.target
After=network-online.target

[Service]
ExecStart=/usr/local/filebeat-7.16.2-linux-x86_64/filebeat -c /usr/local/filebeat-7.16.2-linux-x86_64/filebeat.yml
Restart=always
RestartSec=1
StartLimitIntervalSec=0

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
#kill -9 `ps fax| grep filebea | grep -v grep  | awk '{ print $1 }'`
systemctl restart filebeat && systemctl enable filebeat
grep 192.168.32.91 /etc/hosts
# 判断是否已经添加hosts
if [ $? -ne 0 ]; then
cat >> /etc/hosts << EOF
192.168.32.165 es-4
192.168.32.91  es-5
192.168.32.149 es-6
EOF
else
    echo "installed already!"
fi
# 删除安装包
rm -rf filebeat-7.16.2-linux-x86_64.tar.gz*
# 删除脚本
rm $0
