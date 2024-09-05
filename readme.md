
# Azure DevOps Infrastructure with Jenkins, AKS, NGINX Ingress, Cert Manager, Redis, and Metrics Server

This project provisions an Azure DevOps infrastructure using Terraform. The resources include a Jenkins server on a VM, an Azure Kubernetes Service (AKS) cluster, and additional services like NGINX Ingress Controller, Cert Manager (with external DNS and workload identity), Redis, and the Metrics Server installed using Helm.

## Project Overview

This Terraform project sets up the following resources in Azure:
1. **Resource Group**: A dedicated resource group for the project.
2. **Virtual Machine**: An Ubuntu-based Jenkins server with Docker and Git installed.
3. **Azure Kubernetes Service (AKS)**: A fully managed Kubernetes cluster.
4. **Azure Container Registry (ACR)**: A private container registry for Docker images.
5. **NGINX Ingress Controller**: Handles ingress traffic with a static public IP.
6. **Cert Manager**: Manages certificates (using Helm) with external DNS and workload identity.
7. **Redis**: Redis Sentinel is installed on the AKS cluster using Helm.
8. **Metrics Server**: Installed using Helm to enable horizontal pod autoscaling (HPA).
9. **Key Vault**: Stores sensitive data securely.
10. **Public IP for NGINX Ingress**: A static public IP for the ingress controller, ensuring that the IP remains even if the ingress service is removed.

## Prerequisites

- Azure Subscription
- SSH public/private key pair for VM access
- Terraform installed locally
- Azure CLI installed and authenticated
- Helm installed locally

## Project Structure

- **main.tf**: Defines all the resources, including the AKS cluster, VM, ACR, and key vault.
- **variables.tf**: Holds the variable definitions for customizable inputs like region, VM size, and AKS node pool configuration.
- **outputs.tf**: Contains output configurations, such as Jenkins' public IP.
- **scripts/**: Contains bash scripts for VM provisioning (e.g., installing Jenkins, Docker, and Git).
- **helm_release**: Defines the deployment of Helm charts for NGINX Ingress, Cert Manager, Redis, and the Metrics Server.

## How to Deploy

1. Clone the repository:
   ```bash
   git clone https://github.com/yourusername/azure-devops-infra.git
   cd azure-devops-infra
   ```

2. Update the `variables.tf` file with your specific values:
   - Subscription ID
   - Location
   - SSH public key path
   - Admin username, etc.

3. Initialize Terraform:
   ```bash
   terraform init
   ```

4. Create the plan:
   ```bash
   terraform plan
   ```

5. Apply the Terraform configuration:
   ```bash
   terraform apply
   ```

6. Once the infrastructure is provisioned, the outputs will display the Jenkins public IP and other key details.

## Helm Deployments

After the AKS cluster is created, Helm is used to deploy:
1. **NGINX Ingress Controller**: With a static IP and DNS configuration.
2. **Cert Manager**: For handling certificates using external DNS and workload identity.
3. **Redis Sentinel**: Installed as a high-availability Redis cluster.
4. **Metrics Server**: Provides resource metrics used by the HPA in AKS.

