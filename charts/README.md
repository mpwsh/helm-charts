# flint-controller

The in-cluster half of [flint](https://github.com/mpwsh/flint). It runs inside the k3s
cluster flint created and makes two kinds of Kubernetes objects true:

| Kind | Scope | Means |
| --- | --- | --- |
| `NodeClaim` | cluster | one node in `spec.region`, created the way `flint node add` would; deleting the claim drains and destroys it |
| `FirewallRule` | namespaced | `spec.port`/`spec.protocol` open on every node, from `spec.cidr`; deleting the rule closes it |

Apps (and operators such as kubetailor) ask for infrastructure by creating these objects.
Only the controller holds the provider key, and it refuses anything outside the policy you
give it: regions, plans, node counts, port range. A refused object is marked `Failed` with
the reason and left alone.

## Install

```sh
helm repo add mpwsh https://charts.mpw.sh
helm install flint-controller mpwsh/flint-controller -n flint --create-namespace \
  --set cluster=kt \
  --set provider.apiKey="$VULTR_API_KEY" \
  --set 'policy.allowedRegions={scl,ewr,mia}'
```

Then, once, from the machine that created the cluster (clusters created by flint ≥ 0.1.7
already have their state in the cluster; older ones need this):

```sh
flint cluster sync kt
```

The controller waits for that Secret (`flint/flint-cluster-kt`) and starts reconciling.

Use a dedicated Vultr API key for the controller, restricted to the nodes' public IPs in the
Vultr console (Account → API → Access Control). Pass it with `provider.existingSecret` to keep
it out of the release values:

```sh
kubectl -n flint create secret generic flint-vultr --from-literal=VULTR_API_KEY="$KEY"
helm install flint-controller mpwsh/flint-controller -n flint --set cluster=kt \
  --set provider.existingSecret=flint-vultr
```

## Use

```sh
kubectl apply -f - <<EOF
apiVersion: flint.mpw.sh/v1
kind: NodeClaim
metadata:
  name: region-scl
spec:
  region: scl
EOF
kubectl get nodeclaims -w
# NAME         REGION   PHASE          NODE          IP              AGE
# region-scl   scl      Provisioning                                 5s
# region-scl   scl      Ready          kt-scl-7f2a   45.63.x.x       3m

kubectl apply -f - <<EOF
apiVersion: flint.mpw.sh/v1
kind: FirewallRule
metadata:
  name: game-udp
  namespace: kubetailor
spec:
  protocol: udp
  port: "27015"
EOF
kubectl get firewallrules -A
```

`flint node ls kt` and `flint cluster status kt` on your machine show the same nodes: the
CLI reads the in-cluster state whenever it can reach the cluster.

## Values

| Key | Default | Meaning |
| --- | --- | --- |
| `cluster` | — | **Required.** Name given to `flint cluster create`. |
| `stateNamespace` | release namespace | Namespace of the `flint-cluster-<cluster>` Secret. |
| `provider.name` | `vultr` | Provider. |
| `provider.apiKey` | `""` | Provider API key; the chart makes a Secret for it. |
| `provider.existingSecret` | `""` | Use this Secret instead (key `provider.existingSecretKey`, default `VULTR_API_KEY`). |
| `policy.allowedRegions` | `[]` (any) | Regions a NodeClaim may name. |
| `policy.allowedPlans` | `[]` | Plans a NodeClaim may name, on top of the default plan. |
| `policy.defaultPlan` | first server's plan | Plan for claims that name none. |
| `policy.maxNodes` | `5` | Most nodes in the cluster, servers included. |
| `policy.maxNodesPerRegion` | `1` | Most nodes per region, servers included. |
| `policy.portRange` | `1024-65535` | Ports a FirewallRule may open. Cluster ports (22, 2379-2380, 6443, 8472, 10250, 51820) never. |
| `policy.resyncSeconds` | `600` | Interval of the full firewall re-sync. |
| `crds.install` | `true` | Install the CRDs (kept on uninstall). |
| `rbac.create` | `true` | ClusterRole + Roles for the state Secret and kube-system bootstrap tokens. |
| `serviceAccount.create` / `.name` | `true` / generated | ServiceAccount. |
| `verbosity` | `0` | `-v` count (0 info, 1 debug, 2 trace). |
| `image.repository` / `.tag` | `mpwsh/flint` / appVersion | Image. |

## How it behaves

- One node per claim. Limits count every node in the cluster state that is not being
  removed, servers included, so with `maxNodesPerRegion: 1` a claim for the server's region
  is refused: that region already has a node.
- Provisioning takes a few minutes; the claim is `Provisioning` meanwhile and `Ready` when
  the node reports Ready. A failure destroys the half-made instance, marks the claim
  `Failed` with the reason and tries again 30 minutes later (`status.retryAfter`).
- The provider firewall is set to the cluster's base rules plus every valid `FirewallRule`
  after any change, and every `policy.resyncSeconds` regardless. Node additions and removals
  include the rules too, so a port never flaps while a node comes or goes.
- One replica. Provider calls are serialized in-process; there is no leader election.

## CRDs

`templates/crds.yaml` is `flint controller --print-crds` with a keep policy. Regenerate it
when the types in `crates/core/src/crd.rs` change.
