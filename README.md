# Amazon Web Services

Export global variables

```shell
export AWS_PROFILE=<MY_PROFILE>
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
export AWS_REGION=eu-west-1
export EKS_CLUSTER_NAME="security"
export R53_HOSTED_ZONE_ID=<R53_HOSTED_ZONE_ID>
export ACM_VAULT_ARN=<ACM_VAULT_ARN>
export PUBLIC_DNS_NAME=<PUBLIC_DNS_NAME>
export TERRAFORM_BUCKET_NAME=bucket-${AWS_ACCOUNT_ID}-${AWS_REGION}-terraform-backend
```

Create s3 bucket for terraform states

```shell
# Create bucket
aws s3api create-bucket \
     --bucket $TERRAFORM_BUCKET_NAME \
     --region $AWS_REGION \
     --create-bucket-configuration LocationConstraint=$AWS_REGION

# Make it not public     
aws s3api put-public-access-block \
    --bucket $TERRAFORM_BUCKET_NAME \
    --public-access-block-configuration "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"

# Enable versioning
aws s3api put-bucket-versioning \
    --bucket $TERRAFORM_BUCKET_NAME \
    --versioning-configuration Status=Enabled
```

Initialize AWS security infrastructure. The states will be saved in AWS.

```shell
cd infra/plan
terraform init \
    -backend-config="bucket=$TERRAFORM_BUCKET_NAME" \
    -backend-config="key=security/terraform-state" \
    -backend-config="region=$AWS_REGION"
```

Complete `plan/terraform.tfvars` and run 

```shell
sed -i "s/<LOCAL_IP_RANGES>/$(curl -s http://checkip.amazonaws.com/)\/32/g; s/<PUBLIC_DNS_NAME>/${PUBLIC_DNS_NAME}/g; s/<AWS_ACCOUNT_ID>/${AWS_ACCOUNT_ID}/g; s/<AWS_REGION>/${AWS_REGION}/g; s/<EKS_CLUSTER_NAME>/${EKS_CLUSTER_NAME}/g; s,<ACM_VAULT_ARN>,${ACM_VAULT_ARN},g;" terraform.tfvars
terraform apply
```

Access the EKS Cluster using

```shell
aws eks --region $AWS_REGION update-kubeconfig --name $EKS_CLUSTER_NAME
kubectl config set-context --current --namespace=vault-server
```

# Vault

Install [vault](https://learn.hashicorp.com/tutorials/vault/getting-started-install) 

Vault reads these environment variables for communication. Set Vault's address, and the initial root token.

```shell
# Make sure you are in the terraform/ directory
# cd plan

export VAULT_ADDR="https://vault.${PUBLIC_DNS_NAME}"
export VAULT_TOKEN="$(aws secretsmanager get-secret-value --secret-id $(terraform output vault_secret_name) --version-stage AWSCURRENT --query SecretString --output text | grep "Initial Root Token: " | awk -F ': ' '{print $2}')"
```

Create credentials:

```shell
ACCESS_KEY=ACCESS_KEY
SECRET_KEY=SECRET_KEY
PROJECT_NAME=web
vault secrets enable -path=company/projects/${PROJECT_NAME} -version=2 kv
vault kv put company/projects/${PROJECT_NAME}/credentials/access key="$ACCESS_KEY"
vault kv put company/projects/${PROJECT_NAME}/credentials/secret key="$SECRET_KEY"
```

Create the policy named my-policy with the contents from stdin

```shell
vault policy write my-policy - <<EOF
# Read-only permissions

path "company/projects/${PROJECT_NAME}/*" {
  capabilities = [ "read" ]
}

EOF
```

Create a token and add the my-policy policy

```shell
VAULT_TOKEN=$(vault token create -policy=my-policy | grep "token" | awk 'NR==1{print $2}')
vault kv get -field=key company/projects/${PROJECT_NAME}/credentials/access
vault kv get -field=key company/projects/${PROJECT_NAME}/credentials/secret
```
