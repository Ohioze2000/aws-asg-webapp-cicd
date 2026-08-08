#!/bin/bash
set -e # Exit immediately if a command exits with a non-zero status

export DEBIAN_FRONTEND=noninteractive

# 1. Update package index and install prerequisites
sudo apt-get update -y
sudo apt-get install -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    unzip \
    wget

# 2. Add Docker's official GPG key
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

# 3. Set up the Docker repository
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# 4. Install Docker Engine
sudo apt-get update -y
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# 5. Allow default ubuntu user to run Docker
sudo usermod -aG docker ubuntu || true

# 6. Download web content from raw GitHub repository zip
mkdir -p /tmp/app && cd /tmp/app
wget -O estate-agency.zip https://raw.githubusercontent.com/Ohioze2000/estate-agency/main/estate-agency.zip

# 7. Extract archive
unzip -o estate-agency.zip

# 8. Navigate into extracted directory (handles 'estate-agency-main' nested folder automatically)
cd estate-agency-* || cd estate-agency

# 9. Build and run Docker container
sudo docker build -t estate-agency .
sudo docker run -d -p 80:80 --name estate-agency-app --restart always estate-agency

# Return to root directory
cd ~

# 10. Install CloudWatch Agent
echo "Starting CloudWatch Agent installation..."
wget https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb -O /tmp/amazon-cloudwatch-agent.deb
sudo dpkg -i /tmp/amazon-cloudwatch-agent.deb
rm -f /tmp/amazon-cloudwatch-agent.deb

# 11. Configure CloudWatch Agent
cat <<'EOF' | sudo tee /opt/aws/amazon-cloudwatch-agent/bin/config.json
{
  "agent": {
    "metrics_collection_interval": 60,
    "run_as_user": "root"
  },
  "metrics": {
    "metrics_collected": {
      "cpu": {
        "metrics_collection_interval": 60,
        "resources": [
          "*"
        ],
        "totalcpu": true
      },
      "disk": {
        "metrics_collection_interval": 60,
        "resources": [
          "/"
        ],
        "measurement": [
          "used_percent",
          "inodes_free"
        ]
      },
      "mem": {
        "metrics_collection_interval": 60,
        "measurement": [
          "mem_used_percent"
        ]
      },
      "swap": {
        "metrics_collection_interval": 60,
        "measurement": [
          "swap_used_percent"
        ]
      }
    },
    "append_dimensions": {
      "InstanceId": "${aws:InstanceId}",
      "InstanceName": "${aws:InstanceName}"
    }
  },
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/cloud-init-output.log",
            "log_group_name": "/ec2/cloud-init-output",
            "log_stream_name": "{instance_id}",
            "retention_in_days": 7
          }
        ]
      }
    },
    "log_stream_name": "{instance_id}"
  }
}
EOF

# 12. Fetch configuration and start agent
sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -c file:/opt/aws/amazon-cloudwatch-agent/bin/config.json -s

echo "Instance setup complete."