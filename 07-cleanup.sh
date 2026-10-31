#!/usr/bin/env bash
# 07-cleanup.sh  - SAVE YOUR EVIDENCE FIRST, then run this. Order matters (dependencies).
source ./00-vars.sh      # no "set -e": keep going if one item is already gone

# 1. Compute and credentials
aws ec2 terminate-instances --instance-ids "$BASTION_ID" "$APP_A_ID" "$APP_B_ID" >/dev/null
aws ec2 wait instance-terminated --instance-ids "$BASTION_ID" "$APP_A_ID" "$APP_B_ID"
aws ec2 delete-key-pair --key-name ewb-lab
rm -f ~/.ssh/ewb-lab.pem            # also delete the 3 ewb-* blocks from ~/.ssh/config

# 2. Peering and network dependencies
aws ec2 delete-route --route-table-id "$RT_A_PRIV" --destination-cidr-block 10.20.0.0/16
aws ec2 delete-route --route-table-id "$RT_B_PRIV" --destination-cidr-block 10.10.0.0/16
aws ec2 delete-route --route-table-id "$RT_A_PUB"  --destination-cidr-block 10.20.0.0/16
aws ec2 delete-vpc-peering-connection --vpc-peering-connection-id "$PCX"

for SG in "$SG_BASTION" "$SG_APP_A" "$SG_APP_B"; do aws ec2 delete-security-group --group-id "$SG"; done

for A in "$RTASSOC_A_PUB" "$RTASSOC_A_PRIV" "$RTASSOC_B_PRIV"; do
  aws ec2 disassociate-route-table --association-id "$A"
done
for S in "$SUB_A_PUB" "$SUB_A_PRIV" "$SUB_B_PRIV"; do aws ec2 delete-subnet --subnet-id "$S"; done
for R in "$RT_A_PUB" "$RT_A_PRIV" "$RT_B_PRIV"; do aws ec2 delete-route-table --route-table-id "$R"; done

aws ec2 detach-internet-gateway --internet-gateway-id "$IGW_A" --vpc-id "$VPC_A"
aws ec2 delete-internet-gateway --internet-gateway-id "$IGW_A"
aws ec2 delete-vpc --vpc-id "$VPC_A"
aws ec2 delete-vpc --vpc-id "$VPC_B"

# 3. Verify the account is clear (every command should list nothing for this project)
F="Name=tag:Project,Values=EWB-VPC-Peering"
aws ec2 describe-instances --filters $F --query "Reservations[].Instances[].[InstanceId,State.Name]" --output table
aws ec2 describe-volumes   --filters $F --query "Volumes[].[VolumeId,State]" --output table
aws ec2 describe-vpcs      --filters $F --query "Vpcs[].VpcId" --output table
aws ec2 describe-addresses --query "Addresses[].PublicIp" --output table   # no leftover Elastic IPs
