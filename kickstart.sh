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

echo "Waiting for MCH to be complete..."
oc wait -n open-cluster-management multiclusterhub/multiclusterhub --for=condition=Complete=True

echo "Applying gitops policy..."
oc kustomize kickstarts/phase_3/ --enable-alpha-plugins | oc apply -f -

echo "Labeling hub cluster..."
oc label managedcluster local-cluster gitops=hub --overwrite=true

echo "Removing kubeadmin user..."
echo "Execute: oc -n kube-system delete secret kubeadmin"
