variable "location" {
  type        = string
  description = "Location in Azure in which to deploy the connector"
}

variable "resource_group_name" {
  type        = string
  description = "Name of the Resource Group in which to create the connector"
}

variable "subnet_id" {
  type        = string
  description = "ID of the subnet where the Connector instance should be created"
}

variable "ssh_key_path" {
  type        = string
  description = "Path of your SSH key to upload to instance to allow management access"
}

variable "management_cidrs" {
  type        = list(string)
  description = "CIDR blocks to allow SSH connections from"
  default     = ["0.0.0.0/0"]
}

variable "package_version" {
  type        = string
  description = "Override to use a specific version of connector (e.g. `1.3.0`)"
  default     = ""
}

variable "instance_size" {
  type        = string
  description = "VM instance SKU to use when creating Connector instance"
  default     = "Standard_F2"
}

variable "tags" {
  type        = map(any)
  description = "Add tags to each resource"
  default     = null
}

variable "name_prefix" {
  type        = string
  description = "String to be added in front of all Azure object names"
  default     = "banyan"
}

variable "banyan_host" {
  type        = string
  description = "URL of the Banyan Command Center"
  default     = "https://team.console.banyanops.com/"
}

variable "banyan_api_key" {
  type        = string
  description = "API Key or Refresh Token generated from the Banyan Command Center console"
}

variable "connector_name" {
  type        = string
  description = "Name to use when registering this Connector with the Command Center console"
}
