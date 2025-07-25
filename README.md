# learning-terraform

### 1. Start minikube
```bash
minikube config set cpus 4
minikube config set memory 4096
minikube config set disk-size 100000
minikube config set driver virtualbox
minikube start --container-runtime=containerd
minikube node add --worker=true
```

## 2. Deploy in minikube
```bash
cd env/live
terraform init
terraform plan
find . -type f -name "*.tf" -not -path "./*/.terraform*" -not -path "./*/.git/*" -exec terraform fmt {} \;
terraform apply -var password=password
sudo ip route add 192.168.59.20/32 via 192.168.59.106
kubectl delete all --all --all-namespaces
```

### 5. Get Grafana password
```bash
kubectl get secret -n monitoring grafana -o jsonpath="{.data.admin-password}" | base64 --decode ; echo
```
