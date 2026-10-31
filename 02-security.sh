#!/usr/bin/env bash
# 02-security.sh  - security groups and inbound rules (workbook page 6)
set -euo pipefail
source ./00-vars.sh

MY_IP="$(curl -s https://checkip.amazonaws.com | tr -d '[:space:]')/32"
echo "Your public IP for the bastion SSH rule: $MY_IP"

mksg() {   # mksg NAME VPC_ID -> prints the new group id
  aws ec2 create-security-group --group-name "$1" --description "$1" \
    --vpc-id "$2" --query GroupId --output text
}
allow_ssh() {   # allow_ssh SG_ID SOURCE_CIDR   (TCP 22)
  aws ec2 authorize-security-group-ingress --group-id "$1" \
    --protocol tcp --port 22 --cidr "$2"
}
allow_ping() {  # allow_ping SG_ID SOURCE_CIDR  (ICMP echo request: type 8, code 0)
  aws ec2 authorize-security-group-ingress --group-id "$1" \
    --ip-permissions "IpProtocol=icmp,FromPort=8,ToPort=0,IpRanges=[{CidrIp=$2}]"
}

save SG_BASTION "$(mksg ewb-sg-bastion "$VPC_A")"; tag "$SG_BASTION" ewb-sg-bastion
save SG_APP_A   "$(mksg ewb-sg-app-a   "$VPC_A")"; tag "$SG_APP_A"   ewb-sg-app-a
save SG_APP_B   "$(mksg ewb-sg-app-b   "$VPC_B")"; tag "$SG_APP_B"   ewb-sg-app-b

# ewb-sg-bastion : SSH only from YOUR current public IP
allow_ssh  "$SG_BASTION" "$MY_IP"

# ewb-sg-app-a   : SSH from bastion private IP, ping from App-B only
allow_ssh  "$SG_APP_A" 10.10.1.10/32
allow_ping "$SG_APP_A" 10.20.1.10/32

# ewb-sg-app-b   : SSH from bastion private IP, ping from App-A only
allow_ssh  "$SG_APP_B" 10.10.1.10/32
allow_ping "$SG_APP_B" 10.10.2.10/32

aws ec2 describe-security-group-rules \
    --filters Name=group-id,Values="$SG_BASTION","$SG_APP_A","$SG_APP_B" \
    --query "SecurityGroupRules[?IsEgress==\`false\`].[GroupId,IpProtocol,FromPort,ToPort,CidrIpv4]" \
    --output table
