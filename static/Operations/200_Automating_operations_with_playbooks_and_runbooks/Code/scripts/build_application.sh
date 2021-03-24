#!/bin/bash

LABEL='latest'
ECR_REPONAME='walab-ops-sample-application'
SAMPLE_APPNAME=$ECR_REPONAME
MAIN_STACK=$1
EMAIL=$2

sudo yum install jq -y -q
AWS_REGION=$(curl --silent http://169.254.169.254/latest/dynamic/instance-identity/document | jq '.region' | sed -e 's/^"//' -e 's/"$//')
AWS_ACCOUNT=$(curl --silent http://169.254.169.254/latest/dynamic/instance-identity/document | jq '.accountId' | sed -e 's/^"//' -e 's/"$//')
RESOURCEID=$(curl --silent http://169.254.169.254/latest/dynamic/instance-identity/document | jq '.instanceId' | sed -e 's/^"//' -e 's/"$//')

aws ec2 describe-tags --filters Name=resource-id,Values=$RESOURCEID Name=tagkey,Values=aws:cloudformation:stack-name

echo '#################################################'
echo 'Script will deploy application with below details'
echo '#################################################'
echo 'Region: ' $AWS_REGION
echo 'Account: '$AWS_ACCOUNT
echo 'Repo Name: '$ECR_REPONAME
echo 'Label: '$LABEL

echo '##############################'
echo 'Building Application Container'
echo '##############################'
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $AWS_ACCOUNT.dkr.ecr.$AWS_REGION.amazonaws.com
docker build -t $ECR_REPONAME ../src/
docker tag $ECR_REPONAME:latest $AWS_ACCOUNT.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPONAME:$LABEL
docker push $AWS_ACCOUNT.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPONAME:$LABEL

echo '########################'
echo 'Deploy Application Stack'
echo '########################'
aws iam create-service-linked-role --aws-service-name ecs.amazonaws.com
aws cloudformation create-stack --stack-name $ECR_REPONAME \
                                --template-body file://../templates/base_app.yml \
                                --parameters ParameterKey=BaselineVpcStack,ParameterValue=$MAIN_STACK \
                                            ParameterKey=ECRImageURI,ParameterValue=$AWS_ACCOUNT.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPONAME:$LABEL \
                                            ParameterKey=NotificationEmail,ParameterValue=$EMAIL \
                                --capabilities CAPABILITY_NAMED_IAM \
                                --tags Key=Application,Value=$SAMPLE_APPNAME

echo '#########################################'
echo 'Waiting for Application Stack to complete'
echo '#########################################'
aws cloudformation wait stack-create-complete --stack-name $ECR_REPONAME