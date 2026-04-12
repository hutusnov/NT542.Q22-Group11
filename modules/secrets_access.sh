echo "==== 4.1.2 Check access to secrets ===="

kubectl get clusterrole,role -A -o json | jq -r '
  def wanted: ["get","list","watch"];
  .items[] as $r
  | [ $r.rules[]?
  | select(
      ((.apiGroups? // [""]) | any(.=="" or .=="*"))
      and ((.resources? // []) | any(.=="secrets" or .=="secrets/*" or .=="*"))
      and ((.verbs? // []) | any(.=="*" or .=="get" or .=="list" or .=="watch"))
    )
  | if ((.verbs? // []) | any(.=="*"))
    then wanted[] else (.verbs[]? | select(IN("get","list","watch"))) end
  ] as $verbs
  | select($verbs | length > 0)
  | "\($r.kind): \($r.metadata.name) (namespace: \($r.metadata.namespace // "cluster-wide")) | verbs: \($verbs | unique | join(","))"
'