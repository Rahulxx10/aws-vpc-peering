# AWS VPC Peering Lab

Two VPCs (10.10.0.0/16 and 10.20.0.0/16) connected by VPC peering, with a public bastion in VPC A and private app servers in each VPC. Built with the AWS CLI in `ap-south-1`.

## Prerequisites
- AWS CLI v2 configured for a lab account (VPC, EC2, key pair and SSM read permissions)
- Bash and OpenSSH (Linux, macOS, or WSL)
- Edit `STUDENT` in `00-vars.sh`

## Run order
```bash
./01-network.sh
./02-security.sh
./03-instances.sh
./05-tests.sh baseline      # Test 01: ping must FAIL before peering
./04-peering-routes.sh
./05-tests.sh               # Tests 02-05
./06-controlled-failure.sh
./07-cleanup.sh             # save evidence first
```

Resource IDs are stored in `~/ewb-ids.env` (not committed). Test output is written to `evidence/`.

## Cost warning
EC2, EBS and public IPv4 can incur charges. Always run `07-cleanup.sh` when finished.
