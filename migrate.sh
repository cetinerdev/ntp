#!/bin/bash
set -x

start () {

echo "Create machine configuration so editing chrony.conf won't trigger reboot"
cat machineconfiguration.yaml -l yaml && sleep 5
oc apply -f machineconfiguration.yaml
oc get machineconfiguration cluster -oyaml

echo "Stop chronyd manually"
oc get nodes -owide --no-headers | awk '{print $6}' | xargs -P0 -I{} ssh core@{}  'echo $(hostname) $(sudo systemctl stop chronyd && systemctl is-active chronyd || date +%H:%M:%S)'

echo "Delete old machine config"
oc delete -f yaml/old

oc wait --for=condition=Updated=true mcp master && oc wait --for=condition=Updated=true mcp worker

echo "Create new machine config"
oc apply -f yaml/new

oc wait --for=condition=Updated=true mcp master && oc wait --for=condition=Updated=true mcp worker

echo "Check chrony.conf"
oc get nodes -owide --no-headers | awk '{print $6}' | xargs -P0 -I{} ssh core@{}  'echo $(hostname) $(cat /etc/chrony.conf | grep server)'

echo "Start chronyd manually and makestep"
oc get nodes -owide --no-headers | awk '{print $6}' | xargs -P0 -I{} ssh core@{}  'echo $(hostname) $(sudo systemctl start chronyd && sleep 2 && sudo chronyc makestep && systemctl is-active chronyd && date +%H:%M:%S)'

echo "Check Time" 
oc get nodes -owide --no-headers | awk '{print $6}' | xargs -P0 -I{} ssh core@{}  'echo $(hostname) $(systemctl is-active chronyd && date +%H:%M:%S)'

}

rollback () {

echo "Create machine configuration so editing chrony.conf won't trigger reboot"
cat machineconfiguration.yaml -l yaml && sleep 5
oc apply -f machineconfiguration.yaml

echo "Stop chronyd manually"
oc get nodes -owide --no-headers | awk '{print $6}' | xargs -P0 -I{} ssh core@{}  'echo $(hostname) $(sudo systemctl stop chronyd && systemctl is-active chronyd || date +%H:%M:%S)'

echo "Delete old machine config"
oc delete -f yaml/new
oc wait --for=condition=Updated=true mcp master && oc wait --for=condition=Updated=true mcp worker

echo "Create new machine config"
oc apply -f yaml/old
oc wait --for=condition=Updated=true mcp master && oc wait --for=condition=Updated=true mcp worker

echo "Check chrony.conf"
oc get nodes -owide --no-headers | awk '{print $6}' | xargs -P0 -I{} ssh core@{}  'echo $(hostname) $(cat /etc/chrony.conf | grep server)'

echo "Start chronyd manually and makestep"
oc get nodes -owide --no-headers | awk '{print $6}' | xargs -P0 -I{} ssh core@{}  'echo $(hostname) $(sudo systemctl start chronyd && sleep 2 && sudo chronyc makestep && systemctl is-active chronyd && date +%H:%M:%S)'


echo "Check Time"
while true; do
  oc get nodes -owide --no-headers | awk '{print $6}' | xargs -P0 -I{} ssh core@{}  'echo $(hostname) $(systemctl is-active chronyd && date +%H:%M:%S)'
done

}


"$@"
