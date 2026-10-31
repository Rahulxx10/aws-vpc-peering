#!/usr/bin/env bash
# 03-instances.sh  - key pair, 3 EC2 instances, SSH config (workbook pages 7-8)
set -euo pipefail
source ./00-vars.sh

# Key pair: the private key is saved ONLY on your laptop
mkdir -p ~/.ssh && chmod 700 ~/.ssh
aws ec2 create-key-pair --key-name ewb-lab --key-type rsa \
    --query KeyMaterial --output text > ~/.ssh/ewb-lab.pem
chmod 400 ~/.ssh/ewb-lab.pem

# Latest Amazon Linux 2023 (x86_64) AMI for this Region
AMI="$(aws ssm get-parameter \
    --name /aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64 \
    --query Parameter.Value --output text)"
echo "Using AMI: $AMI"

launch() {  # launch NAME SUBNET SG PRIVATE_IP PUBLIC_IP(true|false)
  local NIC="DeviceIndex=0,SubnetId=$2,Groups=$3,PrivateIpAddress=$4"
  NIC="$NIC,AssociatePublicIpAddress=$5"
  local TAGS="Tags=[{Key=Name,Value=$1},{Key=Project,Value=EWB-VPC-Peering}"
  TAGS="$TAGS,{Key=Student,Value=$STUDENT}]"
  aws ec2 run-instances --image-id "$AMI" --instance-type t3.micro --key-name ewb-lab \
    --network-interfaces "$NIC" \
    --block-device-mappings \
      'DeviceName=/dev/xvda,Ebs={VolumeSize=8,VolumeType=gp3,DeleteOnTermination=true}' \
    --tag-specifications "ResourceType=instance,$TAGS" "ResourceType=volume,$TAGS" \
    --query 'Instances[0].InstanceId' --output text
}

save BASTION_ID "$(launch ewb-bastion "$SUB_A_PUB"  "$SG_BASTION" 10.10.1.10 true)"
save APP_A_ID   "$(launch ewb-app-a   "$SUB_A_PRIV" "$SG_APP_A"   10.10.2.10 false)"
save APP_B_ID   "$(launch ewb-app-b   "$SUB_B_PRIV" "$SG_APP_B"   10.20.1.10 false)"

echo "Waiting for status checks to pass..."
aws ec2 wait instance-status-ok --instance-ids "$BASTION_ID" "$APP_A_ID" "$APP_B_ID"

save BASTION_IP "$(aws ec2 describe-instances --instance-ids "$BASTION_ID" \
    --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)"
echo "Bastion public IPv4: $BASTION_IP"

# ---- write ~/.ssh/config (ProxyJump through the bastion) ----
cat >> ~/.ssh/config <<EOF

Host ewb-bastion
    HostName $BASTION_IP
    User ec2-user
    IdentityFile ~/.ssh/ewb-lab.pem
    IdentitiesOnly yes

Host ewb-app-a
    HostName 10.10.2.10
    User ec2-user
    IdentityFile ~/.ssh/ewb-lab.pem
    IdentitiesOnly yes
    ProxyJump ewb-bastion

Host ewb-app-b
    HostName 10.20.1.10
    User ec2-user
    IdentityFile ~/.ssh/ewb-lab.pem
    IdentitiesOnly yes
    ProxyJump ewb-bastion
EOF
chmod 600 ~/.ssh/config

echo "== CHECKPOINT 02: capture this output =="
aws ec2 describe-instances --filters Name=tag:Project,Values=EWB-VPC-Peering \
    Name=instance-state-name,Values=running \
    --query "Reservations[].Instances[].[Tags[?Key=='Name']|[0].Value,InstanceId,PrivateIpAddress,PublicIpAddress]" \
    --output table
