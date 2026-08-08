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
    git \
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

# 6. Fetch application source code via Git Clone
rm -rf /tmp/app
mkdir -p /tmp/app && cd /tmp/app
git clone https://github.com/Ohioze2000/estate-agency.git .

# 7. Navigate into cloned repository directory
cd estate-agency

# 8. Unzip the estate-agency.zip file located inside the repository
if [ -f "estate-agency.zip" ]; then
    unzip -o estate-agency.zip
else
    echo "ERROR: estate-agency.zip not found inside repository!" >&2
    exit 1
fi

# 9. If unzipping created a nested directory, navigate into it (or stay if files extracted inline)
if [ -d "estate-agency" ]; then
    cd estate-agency
elif [ -d "estate-agency-main" ]; then
    cd estate-agency-main
fi

# 10. Build and run Docker container
sudo docker build -t estate-agency .
sudo docker rm -f estate-agency-app || true
sudo docker run -d -p 80:80 --name estate-agency-app --restart always estate-agency

# Return to root directory
cd ~

# 11. Install CloudWatch Agent
echo "Starting CloudWatch Agent installation..."
wget https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb -O /tmp/amazon-cloudwatch-agent.deb
sudo dpkg -i /tmp/amazon-cloudwatch-agent.deb
rm -f /tmp/amazon-cloudwatch-agent.deb

# 12. Configure CloudWatch Agent
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

# 13. Fetch configuration and start agent
sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -c file:/opt/aws/amazon-cloudwatch-agent/bin/config.json -s

echo "Instance setup complete."