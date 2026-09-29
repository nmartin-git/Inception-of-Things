# Inception-of-Things

## Inception of Things - Part 1: K3s Lightweight Cluster

This project provisions a multi-node, lightweight Kubernetes (K3s) cluster from scratch using Vagrant. It serves as a solid Infrastructure as Code (IaC) foundation, focusing on network isolation, resource efficiency, and automated provisioning.

### 🏗️ Architecture & Specifications

The environment follows strict predefined infrastructure requirements:
- **Hypervisor**: VirtualBox managed via Vagrant.
- **Operating System**: Debian 12 (Bookworm) - *Selected as the latest stable official Vagrant box fully compatible with VirtualBox.*
- **Network**: Isolated Host-Only network (`192.168.56.0/24`) to ensure a private and secured network.
- **Hardware Limits**: Strictly bridled to 1 vCPU and 1024 MB RAM per node to enforce lightweight operations.

#### Nodes Organization
| Node Role | Hostname (Suffix) | IP Address | K3s Mode |
| :--- | :--- | :--- | :--- |
| **Control Plane** | `<login>S` | `192.168.56.110` | Server |
| **Agent Worker** | `<login>SW` | `192.168.56.111` | Agent |

### 🛠️ Key Engineering Decisions

1. **Script automation**: Both nodes are provisioned fully automatically through Bash scripts (`server.sh` and `worker.sh`). No manual intervention required.
2. **Secure Token Distribution**: Instead of hardcoding the Kubernetes cluster token, the control plane generates it dynamically. The token is then securely passed to the worker node by Vagrant's default `/vagrant` synchronized folder, ensuring credentials are never exposed in the scripts.
3. **Environment-Driven Configuration**: K3s configurations (such as `K3S_URL` and `K3S_TOKEN_FILE`) are injected via environment variables prior to installation, maintaining clean and efficient execution scripts.
4. **Modern Kubernetes Standards**: The control plane uses the modern `control-plane` role nomenclature, fully compliant with v1.24+ Kubernetes versions.

### 📂 Project Structure

```text
p1/
├── Vagrantfile          # Defines infrastructure, network, and limits
└── scripts/
    ├── server.sh        # Provisions the K3s control plane
    └── worker.sh        # Joins the K3s agent to the cluster
```

### 🚀 How to Run
Clone the repository and navigate to the p1 directory.

Start the infrastructure:

```bash
vagrant up
```

Verify the cluster status. SSH into the control plane and check the nodes:

```bash
vagrant ssh <login>S
sudo kubectl get nodes -o wide
```

Both nodes should appear with a `Ready` status.

# Inception of Things - Part 2: K3s and Three Web Applications

This part builds on Part 1 and deploys a single-node K3s server hosting three web applications, all reachable through **one IP address**. An Ingress routes each request to the right application depending on the `Host` header sent by the client.

## 🏗️ Architecture & Specifications

- **Hypervisor:** VirtualBox managed via Vagrant.
- **Operating System:** Debian 12 (Bookworm).
- **Network:** Isolated Host-Only network (`192.168.56.0/24`).
- **Hardware Limits:** 2 vCPUs and 2048 MB RAM (heavier workload than in Part 1).

| Node Role     | Hostname   | IP Address       | K3s Mode |
|---------------|------------|------------------|----------|
| Control Plane | `<login>S` | `192.168.56.110` | Server   |

## 🌐 Routing Overview

| Request                                 | Routed to      | Replicas |
|-----------------------------------------|----------------|----------|
| `Host: app1.com`                        | `app1-service` | 1        |
| `Host: app2.com`                        | `app2-service` | 3        |
| Any other host / no host (default rule) | `app3-service` | 1        |

## 🛠️ Key Engineering Decisions

- **Script automation:** `server.sh` installs K3s in `server` mode with no manual intervention.
- **API bound to the static IP:** the Kubernetes API and node IP are bound to `192.168.56.110`, so the cluster is only reachable through the private network.
- **Built-in Ingress controller:** K3s ships with Traefik, so no extra controller needs to be installed.
- **Host-based routing:** a single Ingress with three rules. The last rule has **no `host` field**, which makes it the catch-all pointing to app3.
- **Load balancing:** app2 runs with 3 replicas behind a Kubernetes Service, which spreads requests across the pods.
- **Declarative manifests:** every application is described in YAML and applied with `kubectl apply`.

## 📂 Project Structure

```
p2/
├── Vagrantfile          # VM definition: 2 CPUs, 2GB RAM, static IP
├── scripts/
│   └── server.sh        # Installs K3s (server mode) on 192.168.56.110
└── confs/
    ├── app1.yaml        # Deployment + Service (1 replica)
    ├── app2.yaml        # Deployment + Service (3 replicas)
    ├── app3.yaml        # Deployment + Service (1 replica)
    └── ingress.yaml     # Host-based routing rules
```

## 🚀 How to Run

Navigate to the `p2` directory and start the infrastructure:

```bash
cd p2
vagrant up
```

SSH into the server and apply the manifests (skip this if the provisioning already does it):

```bash
vagrant ssh <login>S
sudo kubectl apply -f /vagrant/confs/
```

## ✅ Verification

Check the node, the pods and the Ingress:

```bash
sudo kubectl get nodes -o wide   # Ready, control-plane,master
sudo kubectl get pods            # 3 pods for app2, 1 for app1, 1 for app3
sudo kubectl get ingress         # 3 rules
```

Test the routing by `Host` header:

```bash
curl -H "Host: app1.com" http://192.168.56.110      # -> app1
curl -H "Host: app2.com" http://192.168.56.110      # -> app2
curl http://192.168.56.110                          # -> app3 (no Host header)
curl -H "Host: unknown.com" http://192.168.56.110   # -> app3 (default rule)
```

Prove the load balancing on app2. The pod name should change between requests:

```bash
for i in $(seq 1 6); do curl -s -H "Host: app2.com" http://192.168.56.110; done
```

## 🧹Cleanup

```bash
vagrant destroy -f
```