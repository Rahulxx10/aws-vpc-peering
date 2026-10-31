#!/usr/bin/env bash
# 04-peering-routes.sh  - request, accept, activate peering + routes on both sides
# RUN THIS ONLY AFTER you have captured the baseline failure (Test 01).
set -euo pipefail
source ./00-vars.sh

# 1. Request (VPC A = requester, VPC B = accepter, same account + Region)
save PCX "$(aws ec2 create-vpc-peering-connection --vpc-id "$VPC_A" --peer-vpc-id "$VPC_B" \
    --query VpcPeeringConnection.VpcPeeringConnectionId --output text)"
tag "$PCX" ewb-a-b-peer

# 2. Accept (required even inside one account)
aws ec2 accept-vpc-peering-connection --vpc-peering-connection-id "$PCX"

# 3. Wait for Status = active
until [ "$(aws ec2 describe-vpc-peering-connections --vpc-peering-connection-ids "$PCX" \
    --query 'VpcPeeringConnections[0].Status.Code' --output text)" = "active" ]; do
  echo "waiting for peering to become active..."; sleep 3
done
echo "== CHECKPOINT 03: peering is active =="
aws ec2 describe-vpc-peering-connections --vpc-peering-connection-ids "$PCX" \
    --query 'VpcPeeringConnections[0].{Id:VpcPeeringConnectionId,Status:Status.Code,Requester:RequesterVpcInfo.[VpcId,CidrBlock],Accepter:AccepterVpcInfo.[VpcId,CidrBlock]}'

# 4. Routes: BOTH directions (replies need a way back) + the bastion subnet (ProxyJump)
aws ec2 create-route --route-table-id "$RT_A_PRIV" \
    --destination-cidr-block 10.20.0.0/16 --vpc-peering-connection-id "$PCX"   # App-A -> VPC B
aws ec2 create-route --route-table-id "$RT_B_PRIV" \
    --destination-cidr-block 10.10.0.0/16 --vpc-peering-connection-id "$PCX"   # App-B -> VPC A
aws ec2 create-route --route-table-id "$RT_A_PUB" \
    --destination-cidr-block 10.20.0.0/16 --vpc-peering-connection-id "$PCX"   # Bastion -> App-B

echo "== CHECKPOINT 04: capture this output =="
aws ec2 describe-route-tables --route-table-ids "$RT_A_PUB" "$RT_A_PRIV" "$RT_B_PRIV" \
    --query "RouteTables[].{Table:RouteTableId,Subnet:Associations[0].SubnetId,Routes:Routes[].[DestinationCidrBlock,GatewayId||VpcPeeringConnectionId]}" \
    --output json
