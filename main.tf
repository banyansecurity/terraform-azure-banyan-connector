terraform {
  required_providers {
    banyan = {
      source  = "banyansecurity/banyan"
      version = "0.6.3"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0.2"
    }
    time = {
      source = "hashicorp/time"
      version = "0.7.2"
    }
  }
}

provider "azurerm" {
    features {}
}

provider "banyan" {
  api_token = var.banyan_api_key
  host      = var.banyan_host
}

locals {
  tags = merge(var.tags, {
    Provider = "Banyan"
    Name = "${var.connector_name}"
  })
}

resource "banyan_api_key" "connector_key" {
  name              = var.connector_name
  description       = var.connector_name
  scope             = "satellite"
}

resource "banyan_connector" "connector_spec" {
  name                 = var.connector_name
  satellite_api_key_id = banyan_api_key.connector_key.id
}

# wait for a connector to be unhealthy before the API objects can be deleted
resource "time_sleep" "connector_health_check" {
  depends_on = [banyan_connector.connector_spec]

  destroy_duration = "5m"
}

resource "azurerm_network_interface" "connector_nic" {
  name                = "${var.name_prefix}-nic-connector"
  location            = var.location
  resource_group_name = var.resource_group_name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = var.subnet_id
    private_ip_address_allocation = "Dynamic"
  }
}

locals {
  init_script = <<INIT_SCRIPT
#!/bin/bash
# use the latest, or set the specific version
LATEST_VER=$(curl -sI https://www.banyanops.com/netting/connector/latest | awk '/Location:/ {print $2}' | grep -Po '(?<=connector-)\S+(?=.tar.gz)')
INPUT_VER=${var.package_version}
VER="$LATEST_VER" && [[ ! -z "$INPUT_VAR" ]] && VER="$INPUT_VER"
# create folder for the Tarball
mkdir -p /opt/banyan-packages
cd /opt/banyan-packages
# download and unzip the files
wget https://www.banyanops.com/netting/connector-$VER.tar.gz
tar zxf connector-$VER.tar.gz
cd connector-$VER
# create the config file
echo 'command_center_url: ${var.banyan_host}' > connector-config.yaml
echo 'api_key_secret: ${banyan_api_key.connector_key.secret}' >> connector-config.yaml
echo 'connector_name: ${var.connector_name}' >> connector-config.yaml
./setup-connector.sh
echo 'Port 2222' >> /etc/ssh/sshd_config && /bin/systemctl restart sshd.service
INIT_SCRIPT
}

resource "azurerm_linux_virtual_machine" "connector_vm" {
  name                = "${var.name_prefix}-connector"
  location            = var.location
  resource_group_name = var.resource_group_name
  size                = var.instance_size
  admin_username      = "adminuser"

  tags = local.tags

  network_interface_ids = [
    azurerm_network_interface.connector_nic.id,
  ]

  admin_ssh_key {
    username   = "adminuser"
    public_key = file(var.ssh_key_path)
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

  custom_data = base64encode(local.init_script)
}

resource "azurerm_network_security_group" "connector_sg" {
  name                = "${var.name_prefix}-connector_sg"
  location            = var.location
  resource_group_name = var.resource_group_name

  security_rule {
    name                       = "Connector: Management"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "2222"
    source_address_prefixes    = var.management_cidrs
    destination_address_prefix = azurerm_network_interface.connector_nic.private_ip_address
  }

  security_rule {
    name                       = "Connector: Banyan Global Edge network"
    priority                   = 101
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = azurerm_network_interface.connector_nic.private_ip_address
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "connector_sg_assoc" {
  subnet_id                 = var.subnet_id
  network_security_group_id = azurerm_network_security_group.connector_sg.id

  depends_on = [azurerm_linux_virtual_machine.connector_vm]  
}

