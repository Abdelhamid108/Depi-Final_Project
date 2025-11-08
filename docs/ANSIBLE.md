Here's your enhanced documentation in Markdown format, with some visual aids for better readability!

```markdown
# Ansible Automation Documentation: DEPI Final Project

This document provides a detailed overview of the Ansible automation setup for the DEPI Final Project. It explains the structure, configuration, and step-by-step execution process to provision the entire application environment.

## 1. Project Overview

This Ansible setup is designed to be the second stage of the infrastructure deployment, following the `terraform apply` command. After Terraform creates the EC2 instances, this Ansible project takes over to configure them completely.

The primary goals of this automation are:

*   **Initialization**: Install common packages (like `git`, `acl`) on all servers.
*   **Docker**: Install and configure the Docker engine on all nodes.
*   **Jenkins Environment**:
    *   Install and configure a Jenkins master on the master-node.
    *   Bypass the setup wizard and install necessary plugins automatically.
    *   Prepare all nodes (masters and workers) to act as Jenkins agents by installing Java and setting up SSH keys.
*   **Kubernetes Cluster**:
    *   Bootstrap a full Kubernetes cluster using `kubeadm`.
    *   Install and configure `cri-dockerd` to use Docker as the container runtime.
    *   Initialize the control-plane on the master-node.
    *   Securely join the worker-nodes to the cluster.

## 2. Directory Structure

```
Ansible/
├── ansible.cfg
├── site.yml
│
├── inventory/
│   ├── hosts.ini
│   ├── group_vars/
│   │   ├── all.yml
│   │   ├── masters.yml
│   │   └── workers.yml
│
├── playbooks/
│   ├── 1.initialization.yml
│   ├── 2.docker_installation.yml
│   ├── 3.jenkins_agents_setup.yml
│   ├── 4.jenkins_master_setup.yml
│   └── 5.k8s_cluster_setup.yml
│
└── roles/
    ├── initialization/
    │   └── tasks/
    │       └── main.yml
    │
    ├── Docker_installation/
    │   ├── tasks/
    │   │   └── main.yml
    │   ├── handlers/
    │   │   └── main.yml
    │   └── templates/
    │       └── daemon.json.j2
    │
    ├── jenkins_master_setup/
    │   ├── tasks/
    │   │   └── main.yml
    │   ├── handlers/
    │   │   └── main.yml
    │   └── vars/
    │       └── main.yml
    │
    ├── jenkins_agents_setup/
    │   ├── tasks/
    │   │   └── main.yml
    │   ├── handlers/
    │   │   └── main.yml
    │   └── files/
    │       └── depi_jenkins_rsa.pub
    │
    ├── k8s_common/
    │   └── tasks/
    │       └── main.yml
    │
    ├── k8s_master/
    │   ├── tasks/
    │   │   └── main.yml
    │   └── vars/
    │       └── main.yml
    │
    └── k8s_worker/
        └── tasks/
            └── main.yml
```

## 3. Prerequisites

Before you can run the main `ansible-playbook` command, you must complete these crucial steps.

### Step 1: Run Terraform

You **must** first successfully run `terraform apply` from the `Terraform/` directory. This step is crucial because it:

*   Creates the EC2 instances (master and workers).
*   Dynamically generates the Ansible inventory file at `Ansible/inventory/hosts.ini`.

### Step 2: Install Ansible

Ansible must be installed on your local machine (the one you are running commands from). Refer to the official Ansible documentation for installation instructions specific to your operating system.

### Step 3: Configure SSH Agent (Critically Important)

This setup is designed to securely access worker nodes that are in a private subnet. You cannot SSH to them directly; you must "jump" through the public master node.

**Why?** The file `Ansible/inventory/group_vars/workers.yml` uses the `ansible_ssh_common_args: "-o ProxyJump=..."` directive. This tells Ansible to SSH to the master node first, and from there, "jump" to the private IP of the worker.

**How?** This `ProxyJump` requires SSH Agent Forwarding. The `ssh-agent` is a program that holds your private key in memory, allowing the master node to use it for the second jump without you having to copy your private key to the master.

You **must** load your private key into the `ssh-agent` before running the playbook.

On macOS or Linux:

```bash
# 1. Start the ssh-agent in the background
# The 'eval' command loads the agent's environment variables into your current shell
eval $(ssh-agent -s)

# 2. Add your private key to the agent
# This is the same key used by Terraform and defined in masters.yml
ssh-add ~/.ssh/DEPI_Project_rsa
```

You only need to do this once per terminal session.

## 4. Directory Structure & Configuration Details

This section explains the key files and their specific functions.

### `ansible.cfg`

```ini
[defaults]
host_key_checking = False  # Disables SSH host key prompts (convenient for automation).
inventory = ./inventory/hosts.ini  # Points to our dynamic inventory file.
remote_user = admin  # Sets the default user for SSH connections.
roles_path = ./roles  # Tells Ansible where to find all the roles.
become = true  # Tells Ansible to use sudo for all tasks, effectively running them as root.
```

### `inventory/`

*   `hosts.ini`: **DYNAMIC FILE**. This is created and updated by Terraform. **Do not edit it manually.**
*   `group_vars/all.yml`: Variables for all hosts. Sets `ansible_user: admin`.
*   `group_vars/masters.yml`: Variables only for the `[masters]` group. Sets the `ansible_ssh_private_key_file` path.
*   `group_vars/workers.yml`: Variables only for the `[workers]` group. This is where the critical `ProxyJump` is configured.

### `roles/`

This project is organized into modular roles, each with a specific purpose.

#### `initialization`

*   **Purpose**: Runs first to install essential packages on all nodes.
*   **Key Tasks**: Updates `apt` cache, installs `git`, `curl`, `vim`, and `acl`.
*   **Note**: `acl` is required to fix a permissions error when Ansible tries to become a non-root user (like our `k8s_manger`).

#### `Docker_installation`

*   **Purpose**: Installs Docker and Docker Compose on all nodes.
*   **Key Tasks**: Adds Docker's official GPG key and repository, installs `docker-ce`, and adds the `admin` user to the `docker` group.
*   **CRITICAL**: This role must also create `/etc/docker/daemon.json` to set the `cgroupdriver` to `systemd`, which is required by Kubernetes.

#### `jenkins_master_setup`

*   **Purpose**: Installs and fully configures the Jenkins master.
*   **Key Tasks**: Adds Jenkins repo, installs `jenkins`, adds `jenkins` user to `docker` group, reads the initialAdminPassword, and runs Groovy scripts to bypass the setup wizard and create an admin user. Installs all plugins defined in `vars/main.yml`.

#### `jenkins_agents_setup`

*   **Purpose**: Prepares all nodes (including the master) to be potential Jenkins agents.
*   **Key Tasks**: Installs `temurin-21-jdk` (Java 21), creates the `jenkins` user, and copies the Jenkins public key (`depi_jenkins_rsa.pub`) to the agents' `authorized_keys` file to allow passwordless SSH from the Jenkins master.

#### `k8s_common_setup`

*   **Purpose**: Prepares all nodes (master and workers) with the base requirements for Kubernetes.
*   **Key Tasks**: Disables swap, loads `overlay` and `br_netfilter` kernel modules, installs `cri-dockerd` (the Docker-Kubernetes translator), and installs `kubelet`, `kubeadm`, and `kubectl`. It also "holds" the packages to prevent unintended automatic updates.

#### `k8s_master_setup`

*   **Purpose**: Bootstraps the Kubernetes control-plane on the master node.
*   **Key Tasks**: Pulls K8s images, runs `kubeadm init`, creates a dedicated `k8s_manger` user for security, copies the `admin.conf` to that user's home, and installs the Calico CNI (network).
*   **Key Output**: It generates a `kubeadm join` command and saves it as a variable (`join_command`) on `localhost` using `delegate_to: localhost` and `delegate_facts: true`.

#### `k8s_worker_setup`

*   **Purpose**: Joins the worker nodes to the cluster.
*   **Key Tasks**: Runs `kubeadm reset` (to ensure a clean state) and then executes the `join_command` that was saved by the master play. It reads this variable from `hostvars['localhost']['join_command']`.

## 5. How to Use: Step-by-Step Execution

Follow these steps precisely to deploy your environment.

### Step 1: Build Infrastructure with Terraform

First, navigate to your Terraform directory and apply the infrastructure.

```bash
cd /path/to/project/Terraform
terraform init
terraform apply -auto-approve # -auto-approve is optional but useful for automation
```

Wait for this to complete. It will create the servers and the `Ansible/inventory/hosts.ini` file.

### Step 2: Prepare SSH Agent

This is crucial for Ansible to connect to the private worker nodes via the master.

```bash
# Start the agent
eval $(ssh-agent -s)

# Add your key (the .pem file from AWS)
ssh-add ~/.ssh/DEPI_Project_rsa
```

### Step 3: Run the Main Ansible Playbook

Now, navigate to your Ansible project root and execute the main playbook.

```bash
cd /path/to/project/Ansible

# Run the main site.yml file
# This single command runs all roles in the correct order.
ansible-playbook site.yml
```
## 6. Playbook Breakdown

You do not need to run the playbooks in `playbooks/` individually. The `site.yml` file orchestrates them for you, ensuring the correct execution order.

### `site.yml`

This is the main entry point for the entire configuration. It runs a series of plays in a specific, required order:

1.  **`gather_facts`**:
    *   **Purpose**: A preliminary play that connects to all hosts and gathers facts (like OS, IP address) for use in later plays.

2.  **`import_playbook: ./playbooks/1.initialization.yml`**:
    *   **Why**: Runs first to install `acl`, which is needed for subsequent tasks that switch users (e.g., the `k8s_manager` user).

3.  **`import_playbook: ./playbooks/2.docker_installation.yml`**:
    *   **Why**: Docker is a prerequisite for both Jenkins (to run Docker commands) and Kubernetes (as the container runtime via `cri-dockerd`).

4.  **`import_playbook: ./playbooks/3.jenkins_agents_setup.yml`**:
    *   **Why**: This installs Java and creates the `jenkins` user, which is needed before the `jenkins_master_setup` play runs to ensure the master can connect to agents.

5.  **`import_playbook: ./playbooks/4.jenkins_master_setup.yml`**:
    *   **Why**: Installs the Jenkins master and its core configurations.

6.  **`import_playbook: ./playbooks/5.k8s_cluster_setup.yml`**:
    *   **Why**: Runs last to build the Kubernetes cluster. This playbook itself is split into three parts: running `k8s_common_setup` on all nodes, `k8s_master_setup` on the master, and `k8s_worker_setup` on the workers.

---
```
