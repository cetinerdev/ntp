#!/bin/bash
export KUBECONFIG=/Users/hcetiner/ocp/ntp/kubeconfig

while true; do
  ts=$(date +%H-%M-%S)
  name="pvc-loop-test-$ts"
  cat <<EOF | oc apply -f - >/dev/null
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: $name
  namespace: rbd-test
spec:
  accessModes: [ReadWriteOnce]
  storageClassName: ocs-external-storagecluster-ceph-rbd
  resources:
    requests:
      storage: 1Gi
---
apiVersion: v1
kind: Pod
metadata:
  name: $name
  namespace: rbd-test
spec:
  restartPolicy: Never
  containers:
    - name: tester
      image: registry.access.redhat.com/ubi9/ubi-minimal:latest
      command: ["sh","-c","echo \$(date) > /data/f && cat /data/f && sleep 2"]
      volumeMounts:
        - mountPath: /data
          name: vol
  volumes:
    - name: vol
      persistentVolumeClaim:
        claimName: $name
EOF
  oc wait --for=condition=Ready pod/$name -n rbd-test --timeout=45s >/dev/null 2>&1

  echo "oc get pvc $name -n rbd-test -o jsonpath='{.status.phase}'"
  echo "$(oc get pvc $name -n rbd-test -o jsonpath='{.status.phase}')"
  echo "Logs:"
  oc logs $name -n rbd-test 
  echo "------------------------------------------------------------------"

  oc delete pod,pvc $name -n rbd-test --wait=true --timeout=30s >/dev/null 2>&1
  sleep 3
done
