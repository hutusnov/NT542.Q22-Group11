echo "==== 4.1.3 Check wildcard usage ===="

kubectl get clusterrole,role -A -o json | jq -r '
  .items[] | select(.rules[]? | 
    ((.apiGroups? // []) | any(. == "*")) or 
    ((.resources? // []) | any(. == "*")) or 
    ((.verbs? // []) | any(. == "*"))
  ) | "Loại: \(.kind) | Tên: \(.metadata.name) | Namespace: \(.metadata.namespace // "N/A")"
'