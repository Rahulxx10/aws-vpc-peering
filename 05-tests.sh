#!/usr/bin/env bash
# 05-tests.sh  - run on your LAPTOP. Saves real output into ./evidence/
# No "set -e": a failing ping is an expected result for Test 01.
source ./00-vars.sh
mkdir -p evidence
OPT="-o StrictHostKeyChecking=accept-new"   # lab shortcut; verify host keys in real life

case "$1" in
baseline)   # Test 01 - run BEFORE 04-peering-routes.sh
  ssh $OPT ewb-app-a 'hostname; hostname -I; ping -c 4 -W 2 10.20.1.10' \
    | tee evidence/01-baseline.txt ;;
*)
  echo "### Test 02 Forward path: App-A -> App-B"
  ssh $OPT ewb-app-a 'hostname; hostname -I; ping -c 4 10.20.1.10' \
    | tee evidence/02-forward.txt

  echo "### Test 03 Reverse path: App-B -> App-A"
  ssh $OPT ewb-app-b 'hostname; hostname -I; ping -c 4 10.10.2.10' \
    | tee evidence/03-reverse.txt

  echo "### Test 04 Private SSH: laptop -> bastion -> App-B"
  ssh $OPT ewb-app-b 'echo "Logged in to $(hostname) via bastion"; whoami' \
    | tee evidence/04-ssh-app-b.txt

  echo "### Test 05 Isolation: no public IPv4 on App-A / App-B"
  aws ec2 describe-instances --filters Name=tag:Project,Values=EWB-VPC-Peering \
    Name=instance-state-name,Values=running \
    --query "Reservations[].Instances[].[Tags[?Key=='Name']|[0].Value,PrivateIpAddress,PublicIpAddress]" \
    --output table | tee evidence/05-isolation.txt ;;
esac
