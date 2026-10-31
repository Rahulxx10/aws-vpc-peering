#!/usr/bin/env bash
# 06-controlled-failure.sh  - remove ONLY the App-B ICMP rule, prove failure, restore, prove recovery
source ./00-vars.sh
mkdir -p evidence
RULE="IpProtocol=icmp,FromPort=8,ToPort=0,IpRanges=[{CidrIp=10.10.2.10/32}]"
OPT="-o StrictHostKeyChecking=accept-new"

{
echo "### A. Before removal (expect 4 replies)"
ssh $OPT ewb-app-a 'ping -c 4 -W 2 10.20.1.10'

echo "### B. Removing ICMP rule from ewb-sg-app-b (SSH rule stays)"
aws ec2 revoke-security-group-ingress --group-id "$SG_APP_B" --ip-permissions "$RULE" >/dev/null
sleep 5
ssh $OPT ewb-app-a 'ping -c 4 -W 2 10.20.1.10'      # expect 100% packet loss

echo "### C. Restoring the exact rule"
aws ec2 authorize-security-group-ingress --group-id "$SG_APP_B" --ip-permissions "$RULE" >/dev/null
sleep 5
ssh $OPT ewb-app-a 'ping -c 4 -W 2 10.20.1.10'      # expect replies again
} 2>&1 | tee evidence/06-controlled-failure.txt
