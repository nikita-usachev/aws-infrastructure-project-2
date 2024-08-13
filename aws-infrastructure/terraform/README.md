# Plan to create infra in AWS

The infrastructure includes components for both the [CORE](./teams/core/) and [TOSU](./teams/tosu/) teams. This Terraform plan creates various resources such as:

- VPC network
- Client VPN
- S3 bucket
- Route53 zones
- EC2 instances
- ECR registries
- ECS cluster
- DocumentDB
- RedisDB
- PostgresDB
- Storage Gateway

## Prerequisites

- [awscli](https://github.com/aws/aws-cli) >= 1.27.53
- [terraform](https://www.terraform.io/downloads.html) >= 1.3.4

## AWS credentials

To authenticate terraform plan AWS credentials should be configured for programmatic access
```bash
aws configure
```
If you use multiple credential profiles defined in `~/.aws/credentials`, choose proper one
```bash
export AWS_PROFILE=<profile-name>
```

## Terraform state backend

Terraform configured to keep it's state on s3 bucket. The configuration is defined in the environment's `backend.tf` file [core/backend.tf](./teams/core/backend.tf) and [tosu/backend.tf](./teams/tosu/backend.tf)
```ini
terraform {
  backend "s3" {
    bucket  = "<terraform-states-bucket-name>"
    key     = "<folder-name>"
    region  = "us-east-2"
    encrypt = true
  }
  required_providers {
    ansible = {
      source  = "nbering/ansible"
      version = "1.0.4"
    }
  }
}
```

__NOTE:__
- Bucket that mentioned in `bucket` key should be created first, if not done yet you can do it with
  ```
  aws s3api create-bucket --bucket terraform-states-quarry --region us-east-2 --create-bucket-configuration LocationConstraint=us-east-2
  ```
- Infrastructure for both environments (CORE/TOSU) are using the same S3 bucket created in CORE account
- Bucket name must be unique across all existing bucket names and comply with DNS naming conventions
- If you create new environment make sure that you are using unique `key` in the terraform backend configuration
- You can override `backend.tf` configuration with terraform CLI arguments:
  ```
  # using separate bucket for environment
  terraform init -backend-config "bucket=terraform-states-custom"
  ```

## Usage

- Terraform contains resources for [CORE](./teams/core/) and [TOSU](./teams/tosu/) teams and has been separate with diffrent directories in [teams/](./teams/) folder.
- Resources are logically grouped using Terraform [workspaces](https://www.terraform.io/cli/workspaces) as environments: `dev`, `prod`, etc.

Init terraform backend
```bash
cd terraform
terraform init
```

List environments:
```bash
terraform workspace list
```

Switch or use the environment:
```bash
terraform workspace select <env-name>
```

### Customization

Per environment configuration files with name `<env-name>.tfvars` are used to customize deployments. E.g. [core/dev.tfvars](./teams/core/dev.tfvars) and [tosu/dev.tfvars](./teams/tosu/dev.tfvars)

__NOTE:__ That we have to set path to the environment's tfvars files explicitly when run terraform commands, e.g. `terraform plan -var-file <env-name>.tfvars`

#### Create new environment

Create workspace for the new environment:
```bash
terraform workspace new <env-name>
```

Copy environment-specific configuration from `dev.tfvars` or any other value's file to `<env-name>.tfvars` and change env related names and variables in it.

__NOTE:__ That we have to set path to the environment tfvars files explicitly when run terraform commands, e.g. `terraform plan -var-file <env-name>.tfvars`

### Create / Update

To create/update the environment execute terraform plan:
```bash
terraform plan -var-file <env-name>.tfvars
terraform apply -var-file <env-name>.tfvars
```

### Destroy

To remove environment's resources run:
```bash
TF_WARN_OUTPUT_ERRORS=1 terraform destroy -var-file <env-name>.tfvars
```

### Generate ansible inventory

Further ansible provisioning automation utilizes dynamic inventory from terraform state, to generate inventory run:

```bash
./create_update_ansible_inventory.sh
```

## Spot price (optional)

You can check price in case spot instances used:
```bash
echo "$(aws ec2 describe-spot-price-history --region us-east-2 --start-time=$(date +%s) --product-descriptions="Linux/UNIX" --query 'max(SpotPriceHistory[*].SpotPrice)' --instance-types t3.medium|tr -d \")"
```

## AWS VPC Peering Setup

This documentation outlines the steps for establishing VPC peering between CORE and TOSU accounts.

__Steps:__

1. __Initiate Peering Request:__ From TOSU (requester) account, send a VPC peering request to account CORE (accepter).
	- Select "another account", region and VPC ID itself of CORE account.
2. __Accept Peering Request:__ In account CORE, accept the VPC peering request initiated by account TOSU.

3. __Configure Route Tables:__ In both accounts (CORE and TOSU), configure the route tables to include a peering connection rule with VPC CIDR and Target of a Peering connection.
	- In each Route Table add a new route, for destination will be CIDR Block of VPC and as a Target choose peering connection, and in drop down menu choose our peering.
	- __Example:__ in account TOSU add a new rule for a Route Table: Destination `172.29.0.0/16` (CIDR Block - Core VPC) - Target: Peering Connection - `pcx-034990adcc25511ae`

4. __Update Security Groups:__ In account TOSU, modify the security group rules to allow traffic from the VPN security group in CORE account. 
	- __Example:__ ACCOUNT_ID/SG_ID `(289075976430/sg-0e3588c36124977fd)`

__NOTE:__ The security group update in step 4 is automated using Terraform. Add the necessary rules in the `.tfvars` parameter named `external_sg_list`.
