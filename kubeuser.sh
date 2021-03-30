#!/bin/bash 


echo "Generating KEY and CSR for $1"
openssl req -nodes -newkey rsa:2048 -subj "/CN=$1/O=system:basic-user" -keyout key.key -out csr.csr 


echo "Generating CertificateSigningRequest for kuber: csr.yml"

cat <<EOF > csr.yml 
apiVersion: certificates.k8s.io/v1
kind: CertificateSigningRequest
metadata:
  name: `echo $1`
spec:
  groups:
  - system:masters
  request: `cat csr.csr | base64 -w 0` 
  signerName: kubernetes.io/kube-apiserver-client
  usages:
  - client auth
EOF


echo "kubectl apply  CertificateSigningRequest"

kubectl apply -f csr.yml

kubectl get csr 

kubectl certificate approve $1


cat <<EOF > config.yml
apiVersion: v1
clusters:
- cluster:
`kubectl config view --flatten --minify | grep --color=never certificate-authority-data`
    server: `TERM=dumb kubectl cluster-info | grep "Kubernetes control plane is running at " | sed 's|Kubernetes control plane is running at ||g'` 
  name: kubernetes
contexts:
- context:
    cluster: kubernetes
    user: `echo $1`
  name: `echo $1`@kubernetes
current-context: `echo $1`@kubernetes
kind: Config
preferences: {}
users:
- name: `echo $1`
  user:
    client-certificate-data: `kubectl get csr $1 -o jsonpath='{.status.certificate}'`
    client-key-data: `cat key.key | base64 -w 0`
EOF


kubectl create clusterrolebinding $1 --clusterrole=cluster-admin --user="$1"


