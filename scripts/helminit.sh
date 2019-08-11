#!bin/baah
sudo add-apt-repository ppa:masterminds/glide && sudo apt-get update
sudo apt-get install glide -y
cd /home/infra/
curl -LO https://git.io/get_helm.sh
chmod 700 get_helm.sh
./get_helm.sh
export KUBECONFIG=/etc/kubernetes/admin.conf
kubectl create serviceaccount tiller --namespace kube-system
kubectl create -f /yaml/tiller-clusterrolebinding.yaml
helm init --service-account tiller --upgrade
