# kubernetes-aws-vpc-kops-terraform

Example code for
the
[Deploy Kubernetes in an Existing AWS VPC with Kops and Terraform](https://ryaneschinger.com/blog/kubernetes-aws-vpc-kops-terraform/) blog
post.

## tldr

```bash
terraform apply -var name=yourdomain.com

export NAME=$(terraform output cluster_name)
export KOPS_STATE_STORE=$(terraform output state_store)
export ZONES=$(terraform output -json availability_zones | jq -r '.value|join(",")')

kops create cluster \
    --master-zones $ZONES \
    --zones $ZONES \
    --topology private \
    --dns-zone $(terraform output public_zone_id) \
    --networking calico \
    --vpc $(terraform output vpc_id) \
    --target=terraform \
    --out=. \
    ${NAME}

terraform output -json | docker run --rm -i ryane/gensubnets:0.1 | pbcopy

kops edit cluster ${NAME}

# replace *subnets* section with your paste buffer (be careful to indent properly)
# save and quit editor

kops update cluster \
  --out=. \
  --target=terraform \
  ${NAME}

terraform apply -var name=yourdomain.com
```

## using a subdomain

If you want all of your dns records to live under a subdomain in its own hosted
zone, you need to setup route delegation to the new zone. After running
`terraform apply -var name=k8s.yourdomain.com`, you can run the following
commands to setup the delegation:

```bash
cat update-zone.json \
 | jq ".Changes[].ResourceRecordSet.Name=\"$(terraform output name).\"" \
 | jq ".Changes[].ResourceRecordSet.ResourceRecords=$(terraform output -json name_servers | jq '.value|[{"Value": .[]}]')" \
 > update-zone.json

aws --profile=default route53 change-resource-record-sets \
 --hosted-zone-id $(aws --profile=default route53 list-hosted-zones | jq -r '.HostedZones[] | select(.Name=="yourdomain.com.") | .Id' | sed 's/\/hostedzone\///') \
 --change-batch file://update-zone.json
```

Wait until your changes propagate before continuing. You are good to go when

```bash
host -a k8s.yourdomain.com
```

returns the correct NS records.
