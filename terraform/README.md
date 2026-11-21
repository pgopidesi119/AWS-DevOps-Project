# AWS EKS infrastructure

This Terraform configuration creates an AWS VPC spanning three availability zones and an Amazon EKS cluster with a managed node group. The EKS/VPC Terraform configuration is adapted from the Ultimate DevOps Project - AWS. The source project and this project's root license use Apache-2.0.

The configuration creates public and private subnets, an internet gateway, one NAT gateway per public subnet, route tables, EKS IAM roles, the EKS control plane, and managed worker nodes. It only provisions infrastructure; it does not deploy this repository's application into the cluster.

## Prerequisites

- Terraform 1.5 or later
- AWS CLI configured with credentials authorized to create VPC, EC2, EKS, and IAM resources
- An AWS region with the configured Kubernetes version available

Do not commit credentials, `*.tfvars` files, or Terraform state. State is local by default in this copy; protect it because it may contain sensitive infrastructure data. The fixed S3 backend from the source project was intentionally omitted so this configuration does not depend on a bucket or lock table belonging to another account. Configure a unique remote backend if your team needs shared state.

## Deploy

From this directory:

```shell
terraform init
terraform fmt -recursive
terraform validate
terraform plan
terraform apply
```

Review the plan carefully before confirming. The defaults select `us-west-2`, three availability zones, and a `t3.medium` node group; adjust them in a local `terraform.tfvars` file for your account and region. Confirm that the selected EKS version is supported in the target region before applying.

After creation, configure `kubectl` using the output cluster name and your chosen region:

```shell
aws eks update-kubeconfig --region us-west-2 --name my-eks-cluster
```

Destroy the infrastructure when it is no longer needed:

```shell
terraform destroy
```

NAT gateways, EKS control planes, and EC2 worker nodes can incur ongoing charges. Check the AWS pricing for your region and remove the resources when finished.
