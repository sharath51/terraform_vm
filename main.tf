data "azurerm_resource_group" "rg"  {
  name = "gds_clouddevops_poc"

}


# Create Virtual Network
data "azurerm_virtual_network" "myvnet" {
  name                = "INSPSBXDN5VNT01"
  resource_group_name = data.azurerm_resource_group.rg.name
}

# Create Subnet
data "azurerm_subnet" "mysubnet" {
  name                 = "INSPSBXDN5SBN01"
  virtual_network_name = data.azurerm_virtual_network.myvnet.name
  resource_group_name  = data.azurerm_resource_group.rg.name
}


# Create Public IP Address
#resource "azurerm_public_ip" "mypublicip" {
#  name                = "mypublicip-1"
#  resource_group_name = data.azurerm_resource_group.rg.name
#  location            = data.azurerm_resource_group.rg.location
# allocation_method   = "Static"
#  domain_name_label   = "dom123"
 # tags = {
#    environment = "Dev"
#  }
#}

data "azurerm_public_ip" "mypublicip" {
  name                = "testapp-ip"
  resource_group_name = data.azurerm_resource_group.rg.name
}


data "azurerm_network_interface" "myvnic" {
  name                = "testapp318"
  resource_group_name = data.azurerm_resource_group.rg.name
}

# Create Network Interface
#resource "azurerm_network_interface" "myvmnic" {
#  name                = "vmnic-1"
#  location            = data.azurerm_resource_group.rg.location
#  resource_group_name = data.azurerm_resource_group.rg.name

#  ip_configuration {
#    name                          = "internal"
#    subnet_id                     = data.azurerm_subnet.mysubnet.id
#    private_ip_address_allocation = "Dynamic"
#    public_ip_address_id          = data.azurerm_public_ip.mypublicip.id 
#  }
#}

# Resource: Azure Linux Virtual Machine
resource "azurerm_linux_virtual_machine" "mylinuxvm" {
  name                = "mylinuxvm-test"
  computer_name       = "devlinux-vm1" # Hostname of the VM
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = data.azurerm_resource_group.rg.location
  size                = "Standard_DS1_v2"
  admin_username      = "adminuser"
  #admin_password      = "Password1234!@"
  disable_password_authentication = true
  network_interface_ids = [
    data.azurerm_network_interface.myvnic.id
  ]
  
  admin_ssh_key {
    username   = "adminuser"
    public_key = file("~/.ssh/id_rsa.pub")
  }
  os_disk {
    name = "osdisk"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }
  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04-LTS"
    version   = "latest"
  }
  
  #provisioner "remote-exec" {

  #inline= [
  #  "sudo apt update",
  #  "sudo apt upgrade -y",
  #  "sudo apt install -y default-jdk",
  #  "java -version",
  #  "sudo apt-get install -y apache2",
  #  "sudo apt-get install -y tomcat9",
  #  "sudo apt-get install -y libapache2-mod-jk",
  #]
  #connection{
  #  type = "ssh"
  #  host = data.azurerm_public_ip.mypublicip.fqdn
  #  user = "adminuser"
    #password = "Password1234!@"
  #  private_key = file("~/.ssh/id_rsa")
  #}
#}

  
}

#Resource: Creating Network Security Group

resource "azurerm_network_security_group" "mynsg" {
  name                = "MyTestGroup-nsg"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name

  security_rule {
    name                       = "ssh"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
 security_rule {
    name                       = "port-80"
    priority                   = 101
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  security_rule {
    name                       = "port-8080"
    priority                   = 102
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "8080"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

}

resource "azurerm_network_interface_security_group_association" "nsg_as" {
  network_interface_id      = data.azurerm_network_interface.myvnic.id
  network_security_group_id = azurerm_network_security_group.mynsg.id
}



locals {
  number_of_disks = 2
}

resource "azurerm_managed_disk" "mydisk" {
  count                = local.number_of_disks
  name                 = "mydisk-${count.index}"
  location             = data.azurerm_resource_group.rg.location
  resource_group_name  = data.azurerm_resource_group.rg.name
  storage_account_type = "Standard_LRS"
  create_option        = "Empty"
  disk_size_gb         = "1"
}

resource "azurerm_virtual_machine_data_disk_attachment" "mydiskattach" {
  count              = local.number_of_disks 
  managed_disk_id    = azurerm_managed_disk.mydisk.*.id[count.index]
  virtual_machine_id = azurerm_linux_virtual_machine.mylinuxvm.id
  lun                = "${count.index}"
  caching            = "ReadWrite"
}