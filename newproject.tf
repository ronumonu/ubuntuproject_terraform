terraform {
  required_version = ">=1.0.0"
}

provider "azurerm" {
  features {}
  client_id       = "8d83d388-5274-4ece-8cb9-35bcb7bdb717"
  client_secret   = "mZa7Q~FT4J4AJrUnnxKKotxT6iKFqJo.dzhgV"
  tenant_id       = "144f41d9-3a44-420c-a571-64ea858d21d2"
  subscription_id = "ef3deb78-5f0b-43b8-be97-e019bf012778"
}

resource "azurerm_resource_group" "CLrg" {
  name     = "CLrg"
  location = "eastus"
}

resource "azurerm_virtual_network" "CLvnet" {
  name                = "CLvnet"
  location            = "eastus"
  resource_group_name = azurerm_resource_group.CLrg.name
  address_space       = ["10.0.0.0/16"]
}

resource "azurerm_subnet" "CLsnet1" {
  name                 = "CLsnet1"
  address_prefixes     = ["10.0.1.0/24"]
  virtual_network_name = azurerm_virtual_network.CLvnet.name
  resource_group_name  = azurerm_resource_group.CLrg.name
}

resource "azurerm_subnet" "CLsnet2" {
name                 = "CLsnet2"
address_prefixes     = ["10.0.2.0/24"] 
virtual_network_name = azurerm_virtual_network.CLvnet.name
resource_group_name  = azurerm_resource_group.CLrg.name
}

resource "azurerm_network_interface" "newnic1" {
  name                = "newnic1"
  location            = azurerm_resource_group.CLrg.location
  resource_group_name = azurerm_resource_group.CLrg.name

  ip_configuration {
    name                          = "CLipconfig"
    subnet_id                     = azurerm_subnet.CLsnet1.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.vmpip.id
  }
}

resource "azurerm_network_security_group" "CLnsg" {
  name                = "CLnsg"
  location            = azurerm_resource_group.CLrg.location
  resource_group_name = azurerm_resource_group.CLrg.name

  security_rule {
    name                       = "sshaccess"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_virtual_machine" "CLvm" {
  resource_group_name   = azurerm_resource_group.CLrg.name
  name                  = "CLvm"
  vm_size               = "Standard_DS1_v2"
  location              = azurerm_resource_group.CLrg.location
  network_interface_ids = [azurerm_network_interface.newnic1.id]

  storage_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

  storage_os_disk {
    name              = "CLdisk1"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  os_profile {
    computer_name  = "firstvm"
    admin_username = "azureuser"
    admin_password = "Welcome12345!"
  }

  os_profile_linux_config {
    disable_password_authentication = false
  }
  tags = {
    environment = "staging"
  }
}

resource "azurerm_public_ip" "CLpip" {
  name                = "CLpip"
  resource_group_name = azurerm_resource_group.CLrg.name
  location            = azurerm_resource_group.CLrg.location
  allocation_method   = "Dynamic"
}

resource "azurerm_subnet_network_security_group_association" "CLnsg" {
  subnet_id                 = azurerm_subnet.CLsnet1.id
  network_security_group_id = azurerm_network_security_group.CLnsg.id
}

resource "azurerm_lb" "CLlb" {
  name                = "CLlb"
  location            = "eastus"
  resource_group_name = azurerm_resource_group.CLrg.name

  frontend_ip_configuration {
    name                 = "PublicIPAddress"
    public_ip_address_id = azurerm_public_ip.CLpip.id
  }
}

resource "azurerm_lb_backend_address_pool" "CLlb" {
  loadbalancer_id = azurerm_lb.CLlb.id
  name            = "BackEndAddressPool"
}

resource "azurerm_public_ip" "vmpip" {
  name                = "vmpip"
  resource_group_name = azurerm_resource_group.CLrg.name
  location            = azurerm_resource_group.CLrg.location
  allocation_method   = "Dynamic"
}