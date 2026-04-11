echo "==== 4.1.4 Check default service accounts ===="

echo "Các Service Accounts mặc định chưa được tắt"
kubectl get serviceaccounts -A -o json | jq -r '
  .items[] | select(.metadata.name=="default" and .automountServiceAccountToken != false) 
  | "Namespace: \(.metadata.namespace)"
'

echo -e "\nCác Pod đang chạy bằng Service Account mặc định"
kubectl get pods -A -o json | jq -r '
  .items[] | select(.spec.serviceAccountName=="default") 
  | "Namespace: \(.metadata.namespace) | Pod: \(.metadata.name)"
'