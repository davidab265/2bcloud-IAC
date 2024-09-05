variable "name" {
  description = "The prefix name to use for all resources."
  type        = string
  default     = "my-name"  
}

variable "location" {
  description = "The Azure region where resources will be deployed."
  type        = string
  default     = "East US"  
}

variable "vm_admin_username" {
  description = "The admin username for the Jenkins VM."
  type        = string
  default     = "azureuser"  
}

variable "ssh_public_key_path" {
  description = "The file path of the SSH public key to use for VM authentication."
  type        = string
  default     = "~/.ssh/id_rsa.pub" 
}

variable "domain" {
  description = "Base domain to use for the ingress controller"
  type        = string
}
