
provider "azurerm" {
  features {}
}

variable "name" {
  type        = string
  description = "Name of target resource group"
}

variable "location" {
  type        = string
  default     = "northeurope"
  description = "Location of resources"
}

variable "username" {
  type        = string
  description = "Admin username"
}

variable "ssh_public_key" {
  type        = string
  description = "SSH Public key"
}

data "template_file" "cloud_config" {
  template = file("${path.module}/cloud_config_template.yml")
  vars = {
    username       = var.username
    ssh_public_key = file(var.ssh_public_key)
  }
}

resource "azurerm_resource_group" "main" {
  name     = title(var.name)
  location = title(var.location)
}

resource "azurerm_virtual_network" "main" {
  name                = "${var.name}-network"
  address_space       = ["10.0.0.0/16"]
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
}

resource "azurerm_subnet" "internal" {
  name                 = "internal"
  virtual_network_name = azurerm_virtual_network.main.name
  resource_group_name  = azurerm_resource_group.main.name
  address_prefixes     = ["10.0.2.0/24"]
}

resource "azurerm_public_ip" "main" {
  name                = "${var.name}-public-ip"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  allocation_method   = "Static"
}

resource "azurerm_network_interface" "main" {
  name                = "${var.name}-nic"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  ip_configuration {
    name                          = "testconfiguration"
    subnet_id                     = azurerm_subnet.internal.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.main.id
  }
}


resource "azurerm_linux_virtual_machine" "main" {
  name                  = "${var.name}-cos-vm"
  resource_group_name   = azurerm_resource_group.main.name
  location              = azurerm_resource_group.main.location
  network_interface_ids = [azurerm_network_interface.main.id]
  size                  = "Standard_B1ms"

  admin_username = var.username
  admin_ssh_key {
    username   = var.username
    public_key = file("~/.ssh/id_rsa.pub")
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

  os_disk {
    name                 = "${var.name}-os-disk"
    storage_account_type = "Standard_LRS"
    caching              = "ReadWrite"
  }

  custom_data = base64encode(data.template_file.cloud_config.rendered)
}
