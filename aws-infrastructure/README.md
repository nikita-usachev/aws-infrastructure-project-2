# AWS Cloud

## Infrastructure automation

This repo contains automation tools to manage infrastructure in AWS:
- [terraform](./terraform) - contains terraform plan to create cloud resources (VPC, Client VPN, EC2 Instances, ECS, Route53, DocumentDB)
- [gitlab](./gitlab) - contains instructions to run and configure Gitlab Server and Runners.

### 1st team infrastructure:

![](./images/infra1-design.png)

### 2nd team infrastructure:

![](./images/infra2-design.png)

## Services available:

- `Gitlab Server`:

    You can ssh on the server:
    ```
    ssh -i ./terraform/id_rsa ubuntu@gitlab.aws.internal
    ```

- `MongoDB / DocumentDB`:

    Connection URI:
    ```bash
    mongodb://root:<password>@mongodb-dev.aws.internal:27017
    ```

    The password is set in the terraform's environment variables [here](./terraform/dev.tfvars)

- `ECR / Container Registry`:

  Login to the registry:
  ```bash
  aws ecr get-login-password --region us-east-2 | docker login --username AWS --password-stdin account-id.dkr.ecr.us-east-2.amazonaws.com
  ```

  __NOTE:__ that you need to have appropriate IAM permissions to pull and push images
