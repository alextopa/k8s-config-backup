#!/bin/bash -e

if [ -z "$NAMESPACES" ]; then
    NAMESPACES=$(kubectl get ns -o jsonpath={.items[*].metadata.name})
fi

RESOURCETYPES="${RESOURCETYPES:-"ingress deployment configmap svc rc ds networkpolicy statefulset cronjob pvc"}"
GLOBALRESOURCES="${GLOBALRESOURCES:-"namespace storageclass clusterrole clusterrolebinding customresourcedefinition"}"


# Start kubernetes state export
for resource in $GLOBALRESOURCES; do
    echo "Exporting resource: ${resource}" >/dev/stderr
    kubectl get -o=json "$resource" | jq --sort-keys \
        'del(
          .items[].metadata.annotations."kubectl.kubernetes.io/last-applied-configuration",
          .items[].metadata.annotations."control-plane.alpha.kubernetes.io/leader",
          .items[].metadata.uid,
          .items[].metadata.selfLink,
          .items[].metadata.resourceVersion,
          .items[].metadata.creationTimestamp,
          .items[].metadata.generation
      )' | python3 -c 'import sys, yaml, json; yaml.safe_dump(json.load(sys.stdin), sys.stdout, default_flow_style=False)' >"${resource}.yaml"
done

for namespace in $NAMESPACES; do
     mkdir -p "${namespace}"

    for type in $RESOURCETYPES; do
        echo "[${namespace}] Exporting resources: ${type}" >/dev/stderr

        label_selector=""
        if [[ "$type" == 'configmap' && -z "${INCLUDE_TILLER_CONFIGMAPS:-}" ]]; then
            label_selector="-l OWNER!=TILLER"
        fi

        kubectl --namespace="${namespace}" get "$type" $label_selector -o custom-columns=SPACE:.metadata.namespace,KIND:..kind,NAME:.metadata.name --no-headers | while read -r a b name; do
            [ -z "$name" ] && continue

        # Service account tokens cannot be exported
        if [[ "$type" == 'secret' && $(kubectl get -n "${namespace}" -o jsonpath="{.type}" secret "$name") == "kubernetes.io/service-account-token" ]]; then
            continue
        fi

        kubectl --namespace="${namespace}" get -o=json "$type" "$name" | jq --sort-keys \
        'del(
            .metadata.annotations."control-plane.alpha.kubernetes.io/leader",
            .metadata.annotations."kubectl.kubernetes.io/last-applied-configuration",
            .metadata.creationTimestamp,
            .metadata.generation,
            .metadata.resourceVersion,
            .metadata.selfLink,
            .metadata.uid,
            .spec.clusterIP,
            .status
        )' | python3 -c 'import sys, yaml, json; yaml.safe_dump(json.load(sys.stdin), sys.stdout, default_flow_style=False)' >"${namespace}/${name}.${type}.yaml"
        done
    done
done
