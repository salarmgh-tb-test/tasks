# Task A2 - Debug a Broken Cluster

## Problem Statement

**Scenario**:

- Pods stuck in CrashLoopBackOff
- Service not reachable
- Ingress returns 502
- One node in NotReady (DiskPressure)

## Issue 1: Node in NotReady State (DiskPressure)

### Step 1: Identify Affected Node

```bash
# Find which nodes have the condition
kubectl get nodes
# NAME           STATUS     ROLES    AGE   VERSION
# worker-node-1  NotReady   <none>   30d   v1.34.0
# worker-node-2  Ready      <none>   30d   v1.34.0

# Get detailed node information
kubectl describe node worker-node-1
# Look for:
# - Conditions section (DiskPressure: True)
# - Allocatable vs Capacity
# - Taints applied

# Check node conditions specifically
kubectl get node worker-node-1 -o jsonpath='{.status.conditions[*]}' | jq .
```

### Step 2: Node-level Investigation

```bash
# SSH into the affected node
ssh user@worker-node-1

# Check disk usage
df -h
# Look for filesystems >85% full

# Check specific Kubernetes directories
du -sh /var/lib/kubelet
du -sh /var/lib/docker
du -sh /var/lib/containerd
du -sh /var/log

# Check for large files
find /var/lib -type f -size +100M -exec ls -lh {} \;

# If there isn't in /var/lib
du -sh /*

# Check container images
crictl images
# or for Docker
docker images

# Check for unused containers
crictl ps -a | grep -i exited
```

### Step 3: Root Cause Analysis

| Potential Cause            | Indicators                  | Impact                          |
| -------------------------- | --------------------------- | ------------------------------- |
| Excessive container images | `/var/lib/containerd` large | Node eviction threshold reached |
| Unrotated logs             | `/var/log` filling up       | DiskPressure condition          |
| Orphaned volumes           | Unused PVs mounted          | Disk space consumed             |
| Application logs           | Container stdout/stderr     | Accumulated over time           |

### Step 4: Immediate Remediation

```bash
# Clean up unused container images
crictl rmi --prune

# For Docker runtime check where used more space
docker system df
docker volume ls -f dangling=true
# Based on output choose action
docker system prune # (options which does not have risk on production, like dangling volumes or images and so on)

# Clean up old logs
journalctl --vacuum-time=3d
journalctl --vacuum-size=1G

# Remove old kubelet logs
find /var/log/pods -type f -mtime +7 -delete

# Check and clean container logs
find /var/lib/docker/containers -name "*.log" -size +100M -exec truncate -s 0 {} \;

# Restart kubelet after cleanup to free up opened files space
systemctl restart kubelet

# Verify node recovers
kubectl get node worker-node-1 -w
```

### Step 5: Permanent Fix

**Configure log rotation for containers:**

```json
// /etc/docker/daemon.json (for Docker)
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "50m",
    "max-file": "3"
  }
}
```

**Configure containerd log rotation:**

```toml
# /etc/containerd/config.toml
[plugins."io.containerd.grpc.v1.cri".containerd]
  max_container_log_line_size = 16384

[plugins."io.containerd.grpc.v1.cri"]
  max_concurrent_downloads = 3
```

**Kubelet garbage collection configuration:**

```yaml
# kubelet-config.yaml
apiVersion: kubelet.config.k8s.io/v1beta1
kind: KubeletConfiguration
imageGCHighThresholdPercent: 85
imageGCLowThresholdPercent: 80
evictionHard:
  imagefs.available: "15%"
  memory.available: "100Mi"
  nodefs.available: "10%"
  nodefs.inodesFree: "5%"
```

**Set up monitoring alert:**

```yaml
# PrometheusRule for disk monitoring
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: node-disk-alerts
spec:
  groups:
    - name: node-disk
      rules:
        - alert: NodeDiskPressure
          expr: |
            (node_filesystem_avail_bytes{mountpoint="/"} /
             node_filesystem_size_bytes{mountpoint="/"}) * 100 < 15
          for: 5m
          labels:
            severity: warning
          annotations:
            summary: "Node disk space low"
            description: "Node {{ $labels.instance }} has less than 15% disk space available"
```

---

## Issue 2: Pods in CrashLoopBackOff

### Step 1: Identify Crashing Pods

```bash
# List all pods with issues
kubectl get pods -A | grep -E 'CrashLoopBackOff|Error|OOMKilled'

# Get specific pod details
kubectl get pods -n production -o wide

# Check pod events
kubectl describe pod <pod-name> -n production
# Look for:
# - Last State: Terminated (with exit code and reason)
# - Restart Count
# - Events section
# - Health check problems
# - Container runtime issue, cpu architecture issue, not found executable app
```

### Step 2: Analyze Crash Reason

```bash
# Check current logs
kubectl logs <pod-name> -n production

# Check previous container logs
kubectl logs <pod-name> -n production --previous

# For multi-container pods
kubectl logs <pod-name> -n production -c <container-name> --previous

# Check exit codes
kubectl get pod <pod-name> -n production -o jsonpath='{.status.containerStatuses[0].lastState.terminated}'
```

**Common Exit Codes:**

| Exit Code | Meaning             | Common Cause                      |
| --------- | ------------------- | --------------------------------- |
| 0         | Success             | Application completed normally    |
| 1         | General error       | Application error, missing config |
| 137       | SIGKILL (OOMKilled) | Memory limit exceeded             |
| 139       | SIGSEGV             | Segmentation fault                |
| 143       | SIGTERM             | Graceful termination              |

### Step 3: Common CrashLoopBackOff Causes and Fixes

#### Cause A: OOMKilled

```bash
# Check if OOMKilled
kubectl describe pod <pod-name> | grep -A5 "Last State"
# Reason: OOMKilled

# Fix: Increase memory limits
kubectl edit deployment <deploy-name> -n production
```

#### Cause B: Missing ConfigMap/Secret

```bash
# Check for missing references
kubectl describe pod <pod-name> | grep -E "ConfigMap|Secret"
# Warning: MountVolume.SetUp failed - configmap "app-config" not found

# Fix: Create missing ConfigMap
kubectl create configmap app-config -n production ... (helm, manifest and ...)
```

#### Cause C: Failed Liveness Probe

```bash
# Check events for probe failures
kubectl describe pod <pod-name> | grep -A3 "Liveness"
# Warning: Liveness probe failed: HTTP probe failed with statuscode: 500

# Fix: Adjust probe timing or fix application health endpoint
kubectl edit deployment <deploy-name> -n production
```

#### Cause D: Missing Environment Variables

```bash
# Check logs for missing env vars
kubectl logs <pod-name> --previous | grep -i "error\|missing\|undefined"
# Error: DATABASE_URL environment variable is not set

# Fix: Add missing secret reference
kubectl edit deployment <deploy-name> -n production
```

#### Cause E: Image Pull Issues

```bash
# Check for image pull errors
kubectl describe pod <pod-name> | grep -E "Failed|Pull|ImagePull"
# Warning: Failed to pull image "myregistry.com/app:v1": unauthorized

# Fix: Create/update image pull secret
kubectl create secret docker-registry regcred \
  --docker-server=myregistry.com \
  --docker-username=user \
  --docker-password=password \
  -n production

# Update deployment to use the secret
kubectl edit deployment <deploy-name> -n production
# Add
imagePullSecrets:
- name: regcred
'
```

### Step 4: Permanent Fix

Update manifest,helm

---

## Issue 3: Service Not Reachable

### Step 1: Verify Service Configuration

```bash
# Check service exists and has endpoints
kubectl get svc -n production
kubectl describe svc <service-name> -n production

# Check if endpoints are populated
kubectl get endpoints <service-name> -n production
# If Endpoints shows "<none>", no pods match the selector

# Verify selector matches pod labels
kubectl get svc <service-name> -n production -o yaml
kubectl get pods -n production --show-labels
# If it does not match, update the selector
kubectl edit svc -n production <service-name>
```

### Step 2: Test Service Connectivity

```bash
# Create debug pod
kubectl run debug --image=nicolaka/netshoot -it --rm -- /bin/bash

# Inside debug pod:
# Test DNS resolution
nslookup backend-svc.production.svc.cluster.local

# Test connectivity
curl -v http://backend-svc.production.svc.cluster.local:3000/health

# Check if service IP is routable (it's related to cni, may not work)
ip route get <service-cluster-ip>
# based cni consider checking iptables, routes, tcpdump and so on
```

### Step 3: Common Service Issues and Fixes

#### Issue A: No Endpoints (Selector Mismatch)

```bash
# Check selector vs pod labels
kubectl get svc backend-svc -o yaml | grep -A5 selector
kubectl get pods --show-labels

# Fix: Update selector or pod labels
kubectl edit svc backend-svc -n production
```

#### Issue B: Wrong Port Configuration

```bash
# Verify port mapping
kubectl get svc backend-svc -o yaml
# spec:
#   ports:
#   - port: 80         # Service port
#     targetPort: 3000 # Container port

# Fix port mismatch
kubectl edit svc backend-svc -n production
```

#### Issue C: Pod Not Ready

```bash
# Check if pods are Ready
kubectl get pods -n production -l app=backend
# If READY shows 0/1, readiness probe is failing

# Check readiness probe
kubectl describe pod <pod-name> | grep -A10 "Readiness"
```

### Step 4: Network Policy Issues

```bash
# Check if NetworkPolicies block traffic
kubectl get networkpolicies -n namespace
# if it's the problem update networkpolicy for correct matching, if it's not production or somehow you can tempotarly disable it
kubectl delete networkpolicy default-deny -n namespace
# If service works, NetworkPolicy is the issue
# Fix: Add proper ingress rules
```

---

## Issue 4: Ingress Returns 502

### Step 1: Check Ingress Status

```bash
# List ingress resources
kubectl get ingress -n production

# Describe ingress for events and configuration
kubectl describe ingress <ingress-name> -n production

# Check ingress controller logs
kubectl logs -n ingress-nginx -l app.kubernetes.io/component=controller --tail=100

# Look for error patterns
kubectl logs -n ingress-nginx -l app.kubernetes.io/component=controller | grep -E "502|error|upstream"
```

### Step 2: Verify Backend Service

```bash
# Check if backend service is reachable from ingress controller
kubectl exec -it -n ingress-nginx deploy/ingress-nginx-controller -- curl -v http://backend-svc.production.svc.cluster.local:3000/health

# Check endpoints
kubectl get endpoints backend-svc -n production
```

### Step 3: Common 502 Causes and Fixes

#### Cause A: Backend Pods Not Ready

```bash
# Check pod readiness
kubectl get pods -n production -l app=backend -o wide

# If pods are not ready, check readiness probe
kubectl describe pod <pod-name> | grep -A5 "Readiness"

# Fix: Ensure application starts and health endpoint responds
```

#### Cause B: Service Port Mismatch

```bash
# Ingress expects service on port 80, but service is on 3000
kubectl get ingress app-ingress -o yaml | grep -A10 "backend:"
kubectl get svc backend-svc -o yaml | grep -A5 "ports:"

# Fix ingress backend port
kubectl edit ingress app-ingress -n production
```

#### Cause C: Ingress Controller Cannot Reach Service (NetworkPolicy)

```bash
# Check if NetworkPolicy allows ingress controller
kubectl get networkpolicy -n production -o yaml

# Add rule allowing ingress-nginx namespace
# (See NetworkPolicy fix in Issue 3)
```

#### Cause D: Backend Timeout

```bash
# Check if requests are timing out
kubectl logs -n ingress-nginx deploy/ingress-nginx-controller | grep -i timeout
# Also check application health, resource usage, kubectl top (or monitoring), application may need scale or other fixes

# Fix: Increase timeouts
kubectl annotate ingress app-ingress -n production \
  nginx.ingress.kubernetes.io/proxy-connect-timeout="30" \
  nginx.ingress.kubernetes.io/proxy-send-timeout="300" \
  nginx.ingress.kubernetes.io/proxy-read-timeout="300"
```

#### Cause E: Ingress Class Not Set

```bash
# Check ingressClassName
kubectl get ingress app-ingress -o yaml | grep ingressClassName

# Fix: Set correct ingress class
kubectl patch ingress app-ingress -n production --type='json' -p='[
  {"op": "add", "path": "/spec/ingressClassName", "value": "nginx"}
]'
```

### Step 4: End-to-End Verification

```bash
# Verify complete path
# 1. External → Ingress Controller
curl -v -H "Host: app.example.com" http://<ingress-external-ip>/health

# 2. Ingress Controller → Service
kubectl exec -it -n ingress-nginx deploy/ingress-nginx-controller -- \
  curl -v http://backend-svc.production.svc.cluster.local:3000/health

# 3. Service → Pod
kubectl exec -it debug-pod -- \
  curl -v http://<pod-ip>:3000/health
```

---

## Preventive Measures

1. **Monitoring & Alerting**

   - Set up alerts for node conditions (DiskPressure, MemoryPressure)
   - Monitor pod restart counts
   - Alert on 5xx error rates

2. **Resource Management**

   - Implement LimitRanges for default limits
   - Use ResourceQuotas per namespace
   - Enable VPA for automatic right-sizing

3. **Health Checks**

   - Standardize probe configurations
   - Validate health endpoints in CI/CD
