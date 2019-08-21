#!/usr/bin/env bash
set -e

export DOCKER_ACCOUNT=pprecel
export PROJECT_NAME=kyma-installer
export KYMAPATH=${GOPATH}src/github.com/kyma-project/kyma

### Installation variables
export CLUSTER_NAME=flying-seals-github-connector-master
export GCP_PROJECT=sap-hybris-sf-playground
export GCP_ZONE=europe-west1-c

# Docker login
if [ "$(jq '.auths' ~/.docker/config.json)" = "{}" ]
then
    echo Docker pass:
    docker login -u $DOCKER_ACCOUNT
fi

# Create a cluster
gcloud container --project "$GCP_PROJECT" clusters \
create "$CLUSTER_NAME" --zone "$GCP_ZONE" \
--cluster-version "1.12" --machine-type "n1-standard-4" \
--addons HorizontalPodAutoscaling,HttpLoadBalancing

# Configure kubectl to use your new cluster
gcloud container clusters get-credentials $CLUSTER_NAME --zone $GCP_ZONE --project $GCP_PROJECT

# Add your account as the cluster administrator
kubectl create clusterrolebinding cluster-admin-binding --clusterrole=cluster-admin --user=$(gcloud config get-value account)

# Create and push kyma's docker image
docker build -t $PROJECT_NAME -f $KYMAPATH/tools/kyma-installer/kyma.Dockerfile $KYMAPATH
docker tag $PROJECT_NAME $DOCKER_ACCOUNT/$PROJECT_NAME
docker push $DOCKER_ACCOUNT/$PROJECT_NAME

# Create kyma's yaml deployment
(cat $KYMAPATH/installation/resources/installer.yaml ; echo "---" ; cat $KYMAPATH/installation/resources/installer-cr-cluster.yaml.tpl) > $KYMAPATH/my-kyma.yaml
sed -i.bak "s~eu.gcr.io/kyma-project/develop/installer:[a-zA-Z0-9]*[a-zA-Z0-9]~$DOCKER_ACCOUNT/$PROJECT_NAME~g" $KYMAPATH/my-kyma.yaml
sed -i.bak "s~IfNotPresent~Always~g" $KYMAPATH/my-kyma.yaml
rm -rf $KYMAPATH/my-kyma.yaml.bak

# Install Tiller on your GKE cluster
echo "Installing Kyma with Tiller from master Kyma release\n"
kubectl apply -f $KYMAPATH/installation/resources/tiller.yaml

# Install Kyma from master
echo "Installing Kyma from master"
kubectl apply -f $KYMAPATH/my-kyma.yaml

# Watch installation
echo "Waiting for Kyma..."

function kymaState(){
    echo `kubectl -n default get installation/kyma-installation -o jsonpath={.status.state}`
}

function kymaInstallationState(){
    echo `kubectl -n default get installation/kyma-installation -o jsonpath="Status: {.status.state}, Description: {.status.description}"`
}

COMPONENT=""
while [ "$(kymaState)" != "Installed" ] ;
do
    NEWCOMPONENT=$(kymaInstallationState)
    if [ "${NEWCOMPONENT}" != "${COMPONENT}" ]
    then
        echo  `date +"%T"` ${NEWCOMPONENT};
        sleep 2;
        COMPONENT=${NEWCOMPONENT}
    fi
done

# Get certificates
tmpfile=$(mktemp /tmp/temp-cert.XXXXXX) \
&& kubectl get configmap net-global-overrides -n kyma-installer -o jsonpath='{.data.global\.ingress\.tlsCrt}' | base64 --decode > $tmpfile \
&& sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain $tmpfile \
&& rm $tmpfile

sh $KYMAPATH/installation/scripts/tiller-tls.sh

# Get access 
PASS=$(kubectl get secret admin-user -n kyma-system -o jsonpath="{.data.password}" | base64 --decode)
echo ${PASS}
echo ${PASS} | pbcopy


# Go to page
URL=$(kubectl get virtualservice core-console -n kyma-system -o jsonpath='{ .spec.hosts[0] }')

echo ${URL}

open "https://${URL}"