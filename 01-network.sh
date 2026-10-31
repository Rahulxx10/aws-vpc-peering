#!/usr/bin/env bash
# 01-network.sh  - VPC A, VPC B, subnets, IGW, route tables (workbook pages 5-6)
set -euo pipefail
source ./00-vars.sh

### ---------- VPC A : 10.10.0.0/16 ----------
save VPC_A "$(aws ec2 create-vpc --cidr-block 10.10.0.0/16 \
    --query Vpc.VpcId --output text)"
tag "$VPC_A" ewb-vpc-a

save SUB_A_PUB "$(aws ec2 create-subnet --vpc-id "$VPC_A" --cidr-block 10.10.1.0/24 \
    --availability-zone "$AZ" --query Subnet.SubnetId --output text)"
tag "$SUB_A_PUB" ewb-a-public

save SUB_A_PRIV "$(aws ec2 create-subnet --vpc-id "$VPC_A" --cidr-block 10.10.2.0/24 \
    --availability-zone "$AZ" --query Subnet.SubnetId --output text)"
tag "$SUB_A_PRIV" ewb-a-private
# Subnets in a custom VPC do NOT auto-assign public IPv4 by default - keep it that way.

### ---------- Internet gateway (VPC A only) ----------
save IGW_A "$(aws ec2 create-internet-gateway \
    --query InternetGateway.InternetGatewayId --output text)"
tag "$IGW_A" ewb-igw-a
aws ec2 attach-internet-gateway --internet-gateway-id "$IGW_A" --vpc-id "$VPC_A"

### ---------- Public route table (0.0.0.0/0 -> IGW) ----------
save RT_A_PUB "$(aws ec2 create-route-table --vpc-id "$VPC_A" \
    --query RouteTable.RouteTableId --output text)"
tag "$RT_A_PUB" ewb-rt-a-public
save RTASSOC_A_PUB "$(aws ec2 associate-route-table --route-table-id "$RT_A_PUB" \
    --subnet-id "$SUB_A_PUB" --query AssociationId --output text)"
aws ec2 create-route --route-table-id "$RT_A_PUB" \
    --destination-cidr-block 0.0.0.0/0 --gateway-id "$IGW_A"

### ---------- Private route table A (local route only for now) ----------
save RT_A_PRIV "$(aws ec2 create-route-table --vpc-id "$VPC_A" \
    --query RouteTable.RouteTableId --output text)"
tag "$RT_A_PRIV" ewb-rt-a-private
save RTASSOC_A_PRIV "$(aws ec2 associate-route-table --route-table-id "$RT_A_PRIV" \
    --subnet-id "$SUB_A_PRIV" --query AssociationId --output text)"

### ---------- VPC B : 10.20.0.0/16 (no IGW) ----------
save VPC_B "$(aws ec2 create-vpc --cidr-block 10.20.0.0/16 \
    --query Vpc.VpcId --output text)"
tag "$VPC_B" ewb-vpc-b

save SUB_B_PRIV "$(aws ec2 create-subnet --vpc-id "$VPC_B" --cidr-block 10.20.1.0/24 \
    --availability-zone "$AZ" --query Subnet.SubnetId --output text)"
tag "$SUB_B_PRIV" ewb-b-private

save RT_B_PRIV "$(aws ec2 create-route-table --vpc-id "$VPC_B" \
    --query RouteTable.RouteTableId --output text)"
tag "$RT_B_PRIV" ewb-rt-b-private
save RTASSOC_B_PRIV "$(aws ec2 associate-route-table --route-table-id "$RT_B_PRIV" \
    --subnet-id "$SUB_B_PRIV" --query AssociationId --output text)"

echo "Network built. IDs saved in $IDS"
echo "== CHECKPOINT 01: capture this output =="
aws ec2 describe-route-tables --route-table-ids "$RT_A_PUB" "$RT_A_PRIV" "$RT_B_PRIV" \
    --query "RouteTables[].{Table:RouteTableId,Subnet:Associations[0].SubnetId,Routes:Routes[].[DestinationCidrBlock,GatewayId]}" \
    --output json
