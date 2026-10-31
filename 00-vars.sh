#!/usr/bin/env bash
# 00-vars.sh  - shared settings. Every other script starts with: source ./00-vars.sh
export AWS_DEFAULT_REGION=ap-south-1      # Mumbai
export AWS_PAGER=""
STUDENT="Rahul"                        # <-- CHANGE THIS
AZ="ap-south-1a"                          # same AZ for every subnet
IDS="$HOME/ewb-ids.env"                   # every resource ID is saved here
touch "$IDS"; source "$IDS"

# save NAME VALUE : store an ID in the file and in the current shell
save() { echo "export $1=\"$2\"" >> "$IDS"; export "$1=$2"; }

# tag RESOURCE_ID NAME : apply Name + Project + Student tags
tag() {
  aws ec2 create-tags --resources "$1" --tags Key=Name,Value="$2" \
    Key=Project,Value=EWB-VPC-Peering Key=Student,Value="$STUDENT"
}
