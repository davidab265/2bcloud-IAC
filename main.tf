# //**********************************//
# // the base azure infrastructure part
# //**********************************//

# // retrieve the current client config. used in the KMS resource
data "azurerm_client_config" "current" {}
data "azurerm_subscription" "current" {}

// network
resource "azurerm_virtual_network" "vnet" {
  name                = var.name
  location            = var.location
  resource_group_name = var.name
  address_space       = ["10.80.0.0/16"]
}

resource "azurerm_subnet" "subnet" {
  name                 = var.name
  resource_group_name  = var.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.80.0.0/24"]
}

resource "azurerm_public_ip" "public_ip" {
  name                = "${var.name}-public-ip"
  location            = var.location
  resource_group_name = var.name

  allocation_method   = "Static"
  sku                 = "Standard"  
}

resource "azurerm_network_interface" "nic" {
  name                = var.name
  location            = var.location
  resource_group_name = var.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic" 
    public_ip_address_id          = azurerm_public_ip.public_ip.id
  }
}

// VM
resource "azurerm_linux_virtual_machine" "vm" {
  name                  = "${var.name}-vm"
  resource_group_name   = var.name
  location              = var.location
  size                  = "Standard_D2s_v3"
  zone     = "2"
  admin_username        = var.vm_admin_username

  network_interface_ids = [azurerm_network_interface.nic.id]
  secure_boot_enabled   = true

  admin_ssh_key {
    username   = var.vm_admin_username
    public_key = file(var.ssh_public_key_path)
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }
   custom_data = filebase64("${path.module}/scripts/install_jenkins.sh")

  }


// security
resource "azurerm_network_security_group" "nsg" {
  name                = "${var.name}-nsg"
  location            = var.location
  resource_group_name = var.name

  security_rule {
    name                       = "Allow-HTTP"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Allow-HTTPS"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  security_rule {
    name                       = "Allow-8080"
    priority                   = 1003
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "8080"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }  
    security_rule {
    name                       = "ssh"
    priority                   = 1004
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }


}

resource "azurerm_network_interface_security_group_association" "nsg_association" {
  network_interface_id      = azurerm_network_interface.nic.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}



// Key Vault
resource "azurerm_key_vault" "kv" {
  name                = "${var.name}-kv-new"
  location            = var.location
  resource_group_name = var.name
  sku_name            = "standard"
  tenant_id           = data.azurerm_client_config.current.tenant_id
}

// AKS Kluster
resource "azurerm_kubernetes_cluster" "aks" {
  name                = "${var.name}-aks"
  location            = "East US"
  resource_group_name = var.name
  dns_prefix          = "${var.name}-aks"

  default_node_pool {
    name       = "default"
    node_count = 1
    vm_size    = "standard_b16pls_v2"
  }

  identity {
    type = "SystemAssigned"
  }
}

// ACR
resource "azurerm_container_registry" "acr" {
  name                = "davids"
  location            = var.location
  resource_group_name = var.name
  sku                 = "Basic"
  admin_enabled       = true
}

# //*******************************//
# // the NGINX part (azure & helm)
# //*******************************//

// Static public IP address
resource "azurerm_public_ip" "nginx_ingress_ip" {
  name                = "${var.name}-nginx-ingress-ip"
  resource_group_name = var.name
  location            = var.location
  allocation_method   = "Static"
  sku                 = "Standard"
}


// NGINX Ingress Controller 
resource "helm_release" "nginx_ingress" {
  name       = "nginx-ingress"
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"
  version    = "4.11.2"  

  namespace  = "nginx-ingress"
  create_namespace = true

  set {
    name  = "controller.service.loadBalancerIP"
    value = azurerm_public_ip.nginx_ingress_ip.ip_address
  }

  set {
    name  = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/azure-load-balancer-resource-group"
    value = var.name
  }

  set {
    name  = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/azure-dns-label-name"
    value = "${var.name}-ingress"
  }

  depends_on = [azurerm_kubernetes_cluster.aks]
}


resource "azurerm_dns_zone" "dns_zone" {
  name                = "yourdomain.com"
  resource_group_name = var.name
}

resource "azurerm_dns_a_record" "nginx_ingress" {
  name                = "${var.name}" 
  zone_name           = var.domain
  resource_group_name = var.name
  ttl                 = 300
  records             = [azurerm_public_ip.nginx_ingress_ip.ip_address]
}

# //**********************************//
# // the HELM part
# //**********************************//


# resource "helm_release" "metrics_server" {
#   name       = "metrics-server"
#   chart      = "metrics-server"
#   repository = "https://kubernetes-sigs.github.io/metrics-server/"
#   namespace  = "kube-system"
#   version    = "3.12.0"

#   values = [
#     <<EOF
# args:
#   - --kubelet-insecure-tls
# EOF
#   ]

#   # Ensure that the Metrics Server is installed after the AKS cluster is ready
#   depends_on = [
#     azurerm_kubernetes_cluster.aks
#   ]
# }

// Redis
resource "helm_release" "redis" {
  name       = "redis"
  repository = "oci://registry-1.docker.io/bitnamicharts"
  chart      = "redis"
  version    = "20.0.3"
  namespace  = "redis"
  create_namespace = true

  set {
    name  = "sentinel.enabled"
    value = "true"
  }

  depends_on = [azurerm_kubernetes_cluster.aks]
}



# //**********************************//
# // Cert manager & dependencies
# //**********************************//

# // Cert Manager
# resource "helm_release" "cert_manager" {
#   name       = "cert-manager"
#   repository = "https://charts.jetstack.io"
#   chart      = "cert-manager"
#   namespace  = "cert-manager"
#   version    = "v1.6.3"

#   create_namespace = true

#   set {
#     name  = "installCRDs"
#     value = "true"
#   }

#   set {
#     name  = "extraArgs[0]"
#     value = "--issuer-name=letsencrypt-prod"
#   }

#   depends_on = [
#     azurerm_kubernetes_cluster.aks
#   ]
# }

# // ExternalDNS
# resource "helm_release" "external_dns" {
#   name       = "external-dns"
#   repository = "oci://registry-1.docker.io/bitnamicharts"
#   chart      = "external-dns"
#   namespace  = "kube-system"
#   version    = "8.3.5"

#   create_namespace = false

#   set {
#     name  = "provider"
#     value = "azure"
#   }

#   set {
#     name  = "azure.resourceGroup"
#     value = var.name
#   }

#   set {
#     name  = "azure.tenantId"
#     value = data.azurerm_client_config.current.tenant_id
#   }

#   set {
#     name  = "azure.subscriptionId"
#     value = data.azurerm_client_config.current.subscription_id
#   }

#   set {
#     name  = "azure.aadClientId"
#     value = var.aad_client_id
#   }

#   set {
#     name  = "azure.aadClientSecret"
#     value = var.aad_client_secret
#   }

#   depends_on = [
#     azurerm_kubernetes_cluster.aks
#   ]
# }

# // Configure Workload Identity for Cert Manager
# resource "azurerm_user_assigned_identity" "cert_manager_identity" {
#   resource_group_name = var.name
#   location            = var.location
#   name                = "${var.name}-cert-manager-identity"
# }

# resource "azurerm_role_assignment" "cert_manager_role" {
#   principal_id         = azurerm_user_assigned_identity.cert_manager_identity.principal_id
#   role_definition_name = "Managed Identity Operator"
#   scope                = data.azurerm_subscription.primary.id
# }

# resource "kubernetes_service_account" "cert_manager_sa" {
#   metadata {
#     name      = "cert-manager-sa"
#     namespace = "cert-manager"
#     annotations = {
#       "azure.workload.identity/client-id" = azurerm_user_assigned_identity.cert_manager_identity.client_id
#     }
#   }
# }

# resource "kubernetes_role_binding" "cert_manager_binding" {
#   metadata {
#     name      = "cert-manager-binding"
#     namespace = "cert-manager"
#   }
#   role_ref {
#     api_group = "rbac.authorization.k8s.io"
#     kind      = "Role"
#     name      = "cert-manager-role"
#   }
#   subject {
#     kind      = "ServiceAccount"
#     name      = kubernetes_service_account.cert_manager_sa.metadata[0].name
#     namespace = kubernetes_service_account.cert_manager_sa.metadata[0].namespace
#   }
# }
