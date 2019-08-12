#!/usr/bin/env bash
set -o errexit

### Installation variables
export CLUSTER_NAME=flying-seals-github-connector-tmp
export GCP_PROJECT=sap-hybris-sf-playground
export GCP_ZONE=europe-west1-c
export KYMA_VERSION=1.4.0 # version only for tiller

# Create a cluster
gcloud container --project "$GCP_PROJECT" clusters \
create "$CLUSTER_NAME" --zone "$GCP_ZONE" \
--cluster-version "1.12" --machine-type "n1-standard-4" \
--addons HorizontalPodAutoscaling,HttpLoadBalancing

# Configure kubectl to use your new cluster
gcloud container clusters get-credentials $CLUSTER_NAME --zone $GCP_ZONE --project $GCP_PROJECT

# Add your account as the cluster administrator
kubectl create clusterrolebinding cluster-admin-binding --clusterrole=cluster-admin --user=$(gcloud config get-value account)

# Install Tiller on your GKE cluster
echo "Installing Kyma with Tiller from $KYMA_VERSION Kyma release\n"
kubectl apply -f https://raw.githubusercontent.com/kyma-project/kyma/$KYMA_VERSION/installation/resources/tiller.yaml

# Deploy Kyma
echo "Deploying Kyma...\n"

kubectl apply -f https://github.com/kyma-project/kyma/releases/download/$KYMA_VERSION/kyma-installer-cluster.yaml

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

# Get access 
PASS=$(kubectl get secret admin-user -n kyma-system -o jsonpath="{.data.password}" | base64 --decode)
echo ${PASS}
echo ${PASS} | pbcopy


# Go to page
URL=$(kubectl get virtualservice core-console -n kyma-system -o jsonpath='{ .spec.hosts[0] }')

echo ${URL}

open "https://${URL}"
