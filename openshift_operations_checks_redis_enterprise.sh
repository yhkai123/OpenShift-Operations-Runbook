OpenShift Operations Checks for Redis Enterprise Cluster (REC)
Type-Grouped Runbook for Platform / SRE Teams
Scope: Redis Enterprise Cluster 8+ on OpenShift
Focus: REC, REDB, REAADB, RERC, pods, services, routes, PVCs, endpoints, operator health

Suggested variables
-------------------
export NS="<namespace>"
export REC_NAME="<rec-name>"
export REDB_NAME="<redb-name>"
export REAADB_NAME="<reaadb-name>"
export RERC_NAME="<rerc-name>"

1) Namespace / Project Level
----------------------------
Purpose:
- Confirm you are in the correct namespace
- Confirm Redis resources exist where expected
- Confirm the namespace is not under broad quota or policy pressure

Commands:
oc project ${NS}
oc get all -n ${NS}
oc get events -n ${NS} --sort-by=.lastTimestamp
oc top pod -n ${NS}
oc describe namespace ${NS}

What to watch:
- Large event volume
- Repeated FailedScheduling / Unhealthy / BackOff events
- CPU or memory pressure across Redis pods

2) Operator / Custom Resource Level
-----------------------------------
Purpose:
- Validate that the Redis operator and its custom resources are healthy
- Confirm desired state is reconciling cleanly

Commands:
oc get csv -A | egrep -i 'redis|enterprise'
oc get subscriptions -A | egrep -i 'redis|enterprise'
oc get installplan -A | egrep -i 'redis|enterprise'
oc get crd | egrep 'redisenterpriseclusters|redisenterprisedatabases|redisenterpriseactiveactivedatabases|redisenterpriseremoteclusters'

oc get rec -n ${NS}
oc get redb -n ${NS}
oc get reaadb -n ${NS}
oc get rerc -n ${NS}

oc describe rec ${REC_NAME} -n ${NS}
oc describe redb ${REDB_NAME} -n ${NS}
oc describe reaadb ${REAADB_NAME} -n ${NS}
oc describe rerc ${RERC_NAME} -n ${NS}

oc get rec ${REC_NAME} -n ${NS} -o yaml
oc get redb ${REDB_NAME} -n ${NS} -o yaml
oc get reaadb ${REAADB_NAME} -n ${NS} -o yaml
oc get rerc ${RERC_NAME} -n ${NS} -o yaml

What to watch:
- Conditions not Ready
- Reconcile failures
- Validation / admission errors
- Status drift between spec and status
- Remote cluster association failures for Active-Active

3) Stateful Workload / Pod Level
--------------------------------
Purpose:
- Validate that REC pods are running, stable, and placed correctly
- Detect restarts, CrashLoopBackOff, probe failures, and node skew

Commands:
oc get pods -n ${NS} -o wide
oc get pods -n ${NS} --show-labels
oc get pods -n ${NS} --sort-by=.status.startTime
oc describe pod <pod-name> -n ${NS}
oc logs <pod-name> -n ${NS} --tail=200
oc logs <pod-name> -n ${NS} --previous --tail=200
oc top pod <pod-name> -n ${NS}
oc get pod <pod-name> -n ${NS} -o yaml

Targeted filters:
oc get pods -n ${NS} | egrep 'CrashLoopBackOff|Error|Pending|ContainerCreating|ImagePullBackOff|Terminating'
oc get pods -n ${NS} -o custom-columns='NAME:.metadata.name,PHASE:.status.phase,NODE:.spec.nodeName,READY:.status.containerStatuses[*].ready,RESTARTS:.status.containerStatuses[*].restartCount'

What to watch:
- Any pod not Running / Ready
- Restart counts increasing
- Liveness/readiness probe failures
- Pending due to storage or scheduling
- Uneven placement across nodes / zones

4) StatefulSet / Deployment / Replica Management
------------------------------------------------
Purpose:
- Confirm REC stateful components and supporting deployments are available
- Confirm desired replicas match available replicas

Commands:
oc get statefulsets -n ${NS}
oc get deployments -n ${NS}
oc describe statefulset -n ${NS} <statefulset-name>
oc describe deployment -n ${NS} <deployment-name>
oc rollout status statefulset/<statefulset-name> -n ${NS}
oc rollout status deployment/<deployment-name> -n ${NS}

What to watch:
- Desired != current != ready replicas
- Stuck rollout
- Services manager deployment unavailable
- StatefulSet blocked by PVC or PDB

5) Service / Endpoint / EndpointSlice Level
-------------------------------------------
Purpose:
- Validate that Redis services exist and point to healthy pod IPs
- Confirm service discovery for REC, REDB, and REAADB

Commands:
oc get svc -n ${NS}
oc describe svc -n ${NS} <service-name>
oc get endpoints -n ${NS}
oc describe endpoints -n ${NS} <service-name>
oc get endpointslices -n ${NS}
oc describe endpointslice -n ${NS} <endpointslice-name>

Helpful selectors:
oc get svc -n ${NS} -o wide
oc get endpoints -n ${NS} -o wide

What to watch:
- Services with no backing endpoints
- Endpoint IPs not matching current pod IPs
- Missing 9443 / 8443 / 8070 exposure where expected
- Database service created but no ready endpoint

6) Route / Ingress Exposure
---------------------------
Purpose:
- Validate OpenShift external exposure and routing for UI / API / DB services
- Useful when 8443 or externally exposed service access is failing

Commands:
oc get routes -n ${NS}
oc describe route -n ${NS} <route-name>
oc get ingress -n ${NS}
oc describe ingress -n ${NS} <ingress-name>

TLS and host summary:
oc get routes -n ${NS} -o custom-columns='NAME:.metadata.name,HOST:.spec.host,PORT:.spec.port.targetPort,TERMINATION:.spec.tls.termination'

What to watch:
- Missing route
- Wrong target service or target port
- TLS termination mismatch
- Hostname resolution or certificate mismatch symptoms

7) PersistentVolumeClaim / Storage Level
----------------------------------------
Purpose:
- Validate Redis persistent storage claims and storage class behavior
- Catch PVC pending, attachment, expansion, and capacity pressure issues

Commands:
oc get pvc -n ${NS}
oc describe pvc -n ${NS} <pvc-name>
oc get pv
oc describe pv <pv-name>
oc get storageclass
oc top pod -n ${NS}

Useful summaries:
oc get pvc -n ${NS} -o custom-columns='NAME:.metadata.name,STATUS:.status.phase,SC:.spec.storageClassName,VOLUME:.spec.volumeName,CAPACITY:.status.capacity.storage'
oc get events -n ${NS} --sort-by=.lastTimestamp | egrep -i 'pvc|persistentvolume|mount|attach|detach|filesystem|storage'

What to watch:
- PVC Pending
- Volume mount failures
- Storage class mismatch
- Slow attach / detach
- Capacity pressure reflected in events or app behavior

8) Node Placement / Scheduling / Affinity Level
-----------------------------------------------
Purpose:
- Confirm Redis pods are scheduled on the expected worker nodes
- Validate anti-affinity / tolerations / topology spread behavior

Commands:
oc get pod -n ${NS} -o wide
oc describe pod <pod-name> -n ${NS}
oc get nodes -o wide
oc describe node <node-name>
oc adm top nodes

Placement-focused views:
oc get pod -n ${NS} -o custom-columns='POD:.metadata.name,NODE:.spec.nodeName,PHASE:.status.phase,QOS:.status.qosClass'
oc get events -n ${NS} --sort-by=.lastTimestamp | egrep -i 'FailedScheduling|taint|toleration|affinity|topology|insufficient'

What to watch:
- Redis pods co-located unexpectedly
- FailedScheduling events
- Taints not tolerated
- Worker node pressure causing evictions or reschedules

9) PodDisruptionBudget / Availability Guardrails
------------------------------------------------
Purpose:
- Confirm maintenance and node drains will not violate Redis availability
- Important before patching or cluster operations

Commands:
oc get pdb -n ${NS}
oc describe pdb -n ${NS} <pdb-name>

What to watch:
- allowed disruptions = 0 during planned maintenance
- PDB not matching current replica count
- Node drain blocked because REC quorum would be violated

10) Secrets / Certificates / Config Inputs
------------------------------------------
Purpose:
- Validate operator-managed credentials and TLS material exist
- Catch expired or missing secrets that break 9443 / 8443 / inter-node trust

Commands:
oc get secrets -n ${NS}
oc describe secret -n ${NS} <secret-name>
oc get cm -n ${NS}
oc describe cm -n ${NS} <configmap-name>

Optional certificate inspection:
oc get secret <secret-name> -n ${NS} -o jsonpath='{.data}'

What to watch:
- Missing cluster credential secret
- Recently rotated secrets not reflected in pods
- Certificate-related events / route issues

11) Network Policy / Connectivity Type
--------------------------------------
Purpose:
- Confirm policy is not blocking Redis internal or external communications
- Important for CRDB remote-cluster connectivity and service exposure

Commands:
oc get networkpolicy -n ${NS}
oc describe networkpolicy -n ${NS} <policy-name>
oc get egressnetworkpolicy -n ${NS}
oc get events -n ${NS} --sort-by=.lastTimestamp | egrep -i 'network|connection|timeout|refused|dns'

Cluster diagnostics namespace:
oc get podnetworkconnectivitychecks -n openshift-network-diagnostics
oc get podnetworkconnectivitychecks -n openshift-network-diagnostics -o wide

What to watch:
- Policy blocking pod-to-pod traffic
- Policy blocking route/LB access
- Remote-cluster traffic blocked for Active-Active
- DNS or cluster network degradation

12) Service Account / RBAC Type
-------------------------------
Purpose:
- Confirm operator and workloads retain the permissions needed to reconcile and run

Commands:
oc get sa -n ${NS}
oc get role,rolebinding -n ${NS}
oc get clusterrole,clusterrolebinding | egrep -i 'redis|enterprise'
oc describe sa -n ${NS} <serviceaccount-name>

What to watch:
- Missing role bindings
- Operator unable to watch/update resources
- Permission denied errors in operator logs

13) Events / Failure Signal Type
--------------------------------
Purpose:
- Fastest way to identify why OpenShift is unhappy even when high-level status looks normal

Commands:
oc get events -n ${NS} --sort-by=.lastTimestamp
oc get events -A --sort-by=.lastTimestamp | egrep -i 'redis|enterprise|Failed|BackOff|Unhealthy|Evicted|Mount|Attach|Detach|Probe|Denied'

What to watch:
- Repeating warning events
- Admission / SCC denials
- Probe failures
- Evictions
- Mount or attach errors

14) SCC / Security Context Type
-------------------------------
Purpose:
- Detect OpenShift security policy conflicts that prevent startup or upgrades

Commands:
oc get scc
oc adm policy who-can use scc privileged
oc describe pod <pod-name> -n ${NS}
oc get events -n ${NS} --sort-by=.lastTimestamp | egrep -i 'securitycontext|scc|forbidden|denied|admission'

What to watch:
- Pods denied required SCC
- Admission webhook rejections
- Security context mismatch after upgrade

15) Monitoring / Prometheus Integration Type
--------------------------------------------
Purpose:
- Confirm metrics exposure and scraping path on OpenShift
- Redis Enterprise exposes a dedicated service for metrics on port 8070

Commands:
oc get svc -n ${NS} | egrep '8070|prometheus|metrics'
oc describe svc -n ${NS} <metrics-service-name>
oc get servicemonitor -A | egrep -i 'redis|enterprise'
oc describe servicemonitor -n ${NS} <servicemonitor-name>
oc get podmonitor -A | egrep -i 'redis|enterprise'
oc get prometheusrule -A | egrep -i 'redis|enterprise'

What to watch:
- Metrics service missing
- ServiceMonitor selector mismatch
- Port name mismatch
- Prometheus not scraping REC metrics endpoint

16) Remote Cluster / Active-Active OpenShift Object Type
--------------------------------------------------------
Purpose:
- Validate Kubernetes objects used for Active-Active lifecycle
- Important when CRDB looks unhealthy but infra/root cause is in remote-cluster config

Commands:
oc get reaadb -n ${NS}
oc get rerc -n ${NS}
oc describe reaadb ${REAADB_NAME} -n ${NS}
oc describe rerc ${RERC_NAME} -n ${NS}
oc get reaadb ${REAADB_NAME} -n ${NS} -o yaml
oc get rerc ${RERC_NAME} -n ${NS} -o yaml

What to watch:
- Remote cluster auth/connectivity issues
- Object not Ready
- Spec/status mismatch across regions/clusters

17) Recommended Short Checks by Type
------------------------------------
Pods:
oc get pods -n ${NS} -o wide
oc get events -n ${NS} --sort-by=.lastTimestamp | tail -50

Services:
oc get svc -n ${NS}
oc get endpoints -n ${NS}

Routes:
oc get routes -n ${NS}
oc describe route -n ${NS} <route-name>

Storage:
oc get pvc -n ${NS}
oc get events -n ${NS} --sort-by=.lastTimestamp | egrep -i 'pvc|mount|attach|detach'

Operator/CRs:
oc get rec,redb,reaadb,rerc -n ${NS}
oc describe rec ${REC_NAME} -n ${NS}

Monitoring:
oc get svc -n ${NS} | egrep '8070|metrics'
oc get servicemonitor -A | egrep -i 'redis|enterprise'

18) What matters most operationally
-----------------------------------
Highest priority signals for OpenShift operations:
1. Pods not Ready or restarting
2. Services with no endpoints
3. PVC Pending / mount / attach failures
4. REC / REDB / REAADB / RERC objects not Ready
5. Route / TLS mismatches for externally exposed services
6. Repeated warning events in namespace
7. Scheduling skew, taints, or worker-node pressure
8. Metrics service / ServiceMonitor missing for 8070 scrape path

Notes
-----
- Redis Enterprise for Kubernetes uses CRDs including REC, REDB, REAADB, and RERC.
- The operator creates services for REC / REDB / REAADB exposure and a dedicated service for Prometheus metrics on port 8070.
- Use this file for OpenShift platform validation only; use the separate API health runbook for Redis health state on 9443 and metrics validation on 8070.
