#!/usr/bin/env bash -e
VAULT_ROLE=ocp-cluster-hub

if [ -z "$KUBECONFIG" ]; then
  echo "KUBECONFIG is not set"
  exit 1
fi

echo "Waiting for cluster version to be available..."
oc wait clusterversion/version --for=condition=Available=True
echo "Waiting for cluster version to finish progressing..."
oc wait clusterversion/version --for=condition=Progressing=False

echo "Installing Red Hat ACM"
oc kustomize kickstarts/phase_1/ --enable-alpha-plugins | oc apply -f -

echo "Waiting for ACM to start"
until oc -n open-cluster-management get deployment multiclusterhub-operator
do
  sleep 10;
done

echo "Creating the MultiClusterHub"
oc kustomize kickstarts/phase_2/ --enable-alpha-plugins | oc apply -f -

echo "Checking for hub cluster secret"
set +e
oc -n open-cluster-management get secret hub-vault-secret
if [ $? -ne 0 ]; then
  echo "No vault secret found, creating a new one..."
  vault operator members
  if [ $? -ne 0 ]; then
    echo "Please ensure vault CLI is logged in"
    exit 1
  fi

  echo "Cleaning up existing secrets..."
  vault list --format=json auth/approle/role/${VAULT_ROLE}/secret-id \
    | jq -r '. | join("\n")' \
    | xargs -L 1 -I {} vault write auth/approle/role/${VAULT_ROLE}/secret-id-accessor/destroy secret_id_accessor={}

  ROLE_ID=$(vault read --format=json auth/approle/role/${VAULT_ROLE}/role-id | jq -r '.data.role_id')
  SECRET_INFO=$(vault write --format=json --force auth/approle/role/${VAULT_ROLE}/secret-id)
  SECRET_ID=$(echo $SECRET_INFO | jq -r '.data.secret_id')
  SECRET_ACCESSOR=$(echo $SECRET_INFO | jq -r '.data.secret_id_accessor')
  unset SECRET_INFO
  echo "Vault Secret ID accessor: ${SECRET_ACCESSOR}"

  oc -n open-cluster-management create secret generic hub-vault-secret \
    --from-literal=role-id=${ROLE_ID} \
    --from-literal=secret-id=${SECRET_ID} \
    --from-literal=secret-id-accessor=${SECRET_ACCESSOR}

  unset ROLE_ID SECRET_ID SECRET_ACCESSOR

  echo "Vault secret created"
fi
set -e

echo "Waiting for MCH to be complete..."
oc wait -n open-cluster-management multiclusterhub/multiclusterhub --for=condition=Complete=True

echo "Applying gitops policy..."
oc kustomize kickstarts/phase_3/ --enable-alpha-plugins | oc apply -f -

echo "Labeling hub cluster..."
oc label managedcluster local-cluster gitops=hub --overwrite=true
