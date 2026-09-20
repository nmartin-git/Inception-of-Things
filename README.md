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
