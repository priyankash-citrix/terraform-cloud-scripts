data "azurerm_virtual_network" "openshift-vnet" {
  name                = join("-", [var.openshift_cluster_name, "vnet"])
  resource_group_name = join("-", [var.openshift_cluster_name, "rg"])
}

data "azurerm_network_security_group" "openshift-nsg" {
  name                = join("-", [var.openshift_cluster_name, "nsg"])
  resource_group_name = join("-", [var.openshift_cluster_name, "rg"])
}

data "azurerm_subnet" "openshift-master-subnet" {
  name                 = join("-", [var.openshift_cluster_name, "master-subnet"])
  resource_group_name  = join("-", [var.openshift_cluster_name, "rg"])
  virtual_network_name = join("-", [var.openshift_cluster_name, "vnet"])
}

data "azurerm_subnet" "openshift-worker-subnet" {
  name                 = join("-", [var.openshift_cluster_name, "worker-subnet"])
  resource_group_name  = join("-", [var.openshift_cluster_name, "rg"])
  virtual_network_name = join("-", [var.openshift_cluster_name, "vnet"])
}

