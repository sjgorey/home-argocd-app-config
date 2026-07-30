#!/usr/bin/env bash
# reboot-k3s-node.sh – Cordon, evacuate Longhorn replicas, drain, reboot, restore.
#
# Safe for k3s control-plane nodes that also run Longhorn.
# Run from a host with working kubectl (homelab) and SSH key access to NODE_IP.
#
# Usage: reboot-k3s-node.sh <node-name> <node-ip> [ssh-user]

set -euo pipefail

NODE_NAME="${1:-}"
NODE_IP="${2:-}"
SSH_USER="${3:-$(whoami)}"
KUBECTL="${KUBECTL:-kubectl}"

LONGHORN_NS="longhorn-system"
REPLICA_WAIT_SECS="${REPLICA_WAIT_SECS:-900}"
DRAIN_TIMEOUT="${DRAIN_TIMEOUT:-15m}"
READY_WAIT_SECS="${READY_WAIT_SECS:-600}"

[[ -z "$NODE_NAME" || -z "$NODE_IP" ]] && {
  echo "Usage: $0 <node-name> <node-ip> [ssh-user]"
  exit 1
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Missing required command: $1"
    exit 1
  }
}

need_cmd "$KUBECTL"
need_cmd jq
need_cmd ssh
need_cmd timeout

ssh_node() {
  ssh -o ConnectTimeout=10 -o BatchMode=yes "$SSH_USER@$NODE_IP" "$@"
}

longhorn_node_exists() {
  "$KUBECTL" -n "$LONGHORN_NS" get "nodes.longhorn.io/$NODE_NAME" >/dev/null 2>&1
}

running_replica_count() {
  "$KUBECTL" -n "$LONGHORN_NS" get replicas.longhorn.io -o json \
    | jq --arg node "$NODE_NAME" '
        [.items[]
          | select(.spec.nodeID == $node)
          | select((.status.currentState // "") == "running")
        ] | length'
}

evictable_pod_count() {
  "$KUBECTL" get pod --all-namespaces \
    --field-selector "spec.nodeName=$NODE_NAME" \
    -o json \
    | jq '
      [.items[]
        | select((.status.phase // "") != "Succeeded" and (.status.phase // "") != "Failed")
        | select(
            ((.metadata.ownerReferences // [])
              | map(.kind)
              | index("DaemonSet")
            ) == null
          )
        | select(
            ((.metadata.ownerReferences // [])
              | map(.kind)
              | index("Node")
            ) == null
          )
        | select((.metadata.ownerReferences[0].kind // "") != "InstanceManager")
        | select((.metadata.name // "") | startswith("instance-manager-") | not)
      ] | length'
}

volume_health_summary() {
  "$KUBECTL" -n "$LONGHORN_NS" get volumes.longhorn.io -o json \
    | jq -r '
      [.items[] | .status.robustness // "unknown"]
      | group_by(.)
      | map({(.[0]): length})
      | add
      | to_entries
      | map("\(.key)=\(.value)")
      | join(" ")'
}

# Longhorn keeps instance-manager PDBs at minAvailable=1 even after replicas
# leave the node, which blocks kubectl drain. Open them once evacuation is done.
allow_instance_manager_eviction() {
  local pdbs
  pdbs="$("$KUBECTL" -n "$LONGHORN_NS" get pdb -o json \
    | jq -r --arg node "$NODE_NAME" '
        .items[]
        | select((.metadata.name // "") | startswith("instance-manager-"))
        | select(.spec.selector.matchLabels["longhorn.io/node"] == $node)
        | .metadata.name')"

  if [[ -z "$pdbs" ]]; then
    echo "  No instance-manager PDB found for $NODE_NAME."
    return 0
  fi

  while IFS= read -r pdb; do
    [[ -z "$pdb" ]] && continue
    echo "  Allowing disruption on PDB $pdb"
    "$KUBECTL" -n "$LONGHORN_NS" patch "pdb/$pdb" --type merge \
      -p '{"spec":{"minAvailable":0}}'
  done <<< "$pdbs"
}

echo "=== Restarting k3s node: $NODE_NAME ($NODE_IP) ==="

IS_MASTER="$("$KUBECTL" get node "$NODE_NAME" -o jsonpath='{.metadata.labels.node-role\.kubernetes\.io/control-plane}' 2>/dev/null || true)"
if [[ -n "$IS_MASTER" ]]; then
  echo "WARNING: $NODE_NAME is a control-plane node."
  echo "Reboot only one control-plane node at a time; wait until Ready before the next."
  if [[ -t 0 ]]; then
    read -r -p "Continue? (yes/no): " REPLY
    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
      echo "Aborted."
      exit 1
    fi
  elif [[ "${ASSUME_YES:-}" == "1" ]]; then
    echo "ASSUME_YES=1 set; continuing without prompt."
  else
    echo "Non-interactive shell. Re-run with ASSUME_YES=1 to proceed on a control-plane node."
    exit 1
  fi
fi

echo "Pre-check: SSH + passwordless sudo on $NODE_IP"
ssh_node "sudo -n true"

echo "Pre-check: Longhorn volume robustness: $(volume_health_summary)"

HAS_LONGHORN=0
if longhorn_node_exists; then
  HAS_LONGHORN=1
  echo "Longhorn node found; will evacuate replicas before drain."
else
  echo "No Longhorn node object for $NODE_NAME; skipping Longhorn evacuation."
fi

echo "Cordoning Kubernetes node..."
"$KUBECTL" cordon "$NODE_NAME"

cleanup_on_failure() {
  local rc=$?
  if [[ $rc -ne 0 ]]; then
    echo "ERROR: script failed (exit $rc). Node may still be cordoned."
    if [[ "$HAS_LONGHORN" -eq 1 ]]; then
      echo "Longhorn eviction/scheduling may still be disabled; inspect:"
      echo "  kubectl -n $LONGHORN_NS get nodes.longhorn.io $NODE_NAME -o yaml"
    fi
  fi
}
trap cleanup_on_failure EXIT

if [[ "$HAS_LONGHORN" -eq 1 ]]; then
  echo "Disabling Longhorn scheduling and requesting replica eviction..."
  "$KUBECTL" -n "$LONGHORN_NS" patch "nodes.longhorn.io/$NODE_NAME" --type merge \
    -p '{"spec":{"allowScheduling":false,"evictionRequested":true}}'

  echo "Waiting for running Longhorn replicas to leave $NODE_NAME (max ${REPLICA_WAIT_SECS}s)..."
  deadline=$((SECONDS + REPLICA_WAIT_SECS))
  while true; do
    count="$(running_replica_count)"
    if [[ "$count" -eq 0 ]]; then
      echo "  No running replicas remain on $NODE_NAME."
      break
    fi
    if (( SECONDS >= deadline )); then
      echo "Timed out waiting for Longhorn replicas to evacuate ($count still running)."
      exit 1
    fi
    echo "  Still waiting for $count running replica(s)... ($(date +%T))"
    sleep 10
  done

  echo "Opening Longhorn instance-manager PDBs so drain can proceed..."
  allow_instance_manager_eviction
fi

echo "Draining node (failing on errors)..."
"$KUBECTL" drain "$NODE_NAME" \
  --ignore-daemonsets \
  --delete-emptydir-data \
  --force \
  --grace-period=30 \
  --timeout="$DRAIN_TIMEOUT"

echo "Waiting for remaining evictable pods to terminate..."
deadline=$((SECONDS + 300))
while true; do
  count="$(evictable_pod_count)"
  if [[ "$count" -eq 0 ]]; then
    echo "  All evictable pods have terminated."
    break
  fi
  if (( SECONDS >= deadline )); then
    echo "Timed out waiting for pods to terminate ($count still present)."
    "$KUBECTL" get pod --all-namespaces --field-selector "spec.nodeName=$NODE_NAME" -o wide || true
    exit 1
  fi
  echo "  Still waiting for $count pod(s)... ($(date +%T))"
  sleep 10
done

echo "Rebooting node..."
ssh_node "sudo reboot" || true

echo "Waiting for node to go down..."
sleep 10
deadline=$((SECONDS + 120))
while ssh -o ConnectTimeout=5 -o BatchMode=yes "$SSH_USER@$NODE_IP" "true" 2>/dev/null; do
  if (( SECONDS >= deadline )); then
    echo "Timed out waiting for SSH to drop after reboot."
    exit 1
  fi
  echo "  Node still responding to SSH... ($(date +%T))"
  sleep 5
done
echo "  Node is down."

echo "Waiting for SSH and Kubernetes Ready (max ${READY_WAIT_SECS}s)..."
deadline=$((SECONDS + READY_WAIT_SECS))
while ! ssh -o ConnectTimeout=5 -o BatchMode=yes "$SSH_USER@$NODE_IP" "true" 2>/dev/null; do
  if (( SECONDS >= deadline )); then
    echo "Timed out waiting for SSH to return."
    exit 1
  fi
  echo "  Waiting for SSH... ($(date +%T))"
  sleep 10
done
echo "  SSH is back up."

while [[ "$("$KUBECTL" get node "$NODE_NAME" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo False)" != "True" ]]; do
  if (( SECONDS >= deadline )); then
    echo "Timed out waiting for Kubernetes Ready."
    exit 1
  fi
  echo "  Waiting for node Ready... ($(date +%T))"
  sleep 10
done
echo "  Node is Ready."

if [[ "$HAS_LONGHORN" -eq 1 ]]; then
  echo "Re-enabling Longhorn scheduling and clearing eviction request..."
  "$KUBECTL" -n "$LONGHORN_NS" patch "nodes.longhorn.io/$NODE_NAME" --type merge \
    -p '{"spec":{"allowScheduling":true,"evictionRequested":false}}'

  echo "Longhorn volume robustness: $(volume_health_summary)"
fi

"$KUBECTL" uncordon "$NODE_NAME"
trap - EXIT
echo "Node $NODE_NAME is back and fully schedulable."
