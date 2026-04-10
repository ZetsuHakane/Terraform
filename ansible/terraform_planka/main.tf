# Fichier de déployement 

# Resource Group
resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location
}

# Virtual Network + Subnet
resource "azurerm_virtual_network" "vnet" {
  name                = var.vnet_name
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  address_space       = ["10.0.0.0/16"]
}

resource "azurerm_subnet" "subnet" {
  name                 = var.subnet_name
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

# PostgreSQL Flexible Server
resource "azurerm_postgresql_flexible_server" "postgres" {
  name                          = var.postgres_name
  resource_group_name           = azurerm_resource_group.rg.name
  location                      = azurerm_resource_group.rg.location
  version                       = "15"
  administrator_login           = var.postgres_admin
  administrator_password        = var.postgres_password
  storage_mb                    = 32768
  delegated_subnet_id           = azurerm_subnet.subnet.id
  public_network_access_enabled = false
}

# Container App Environment
resource "azurerm_container_app_environment" "env" {
  name                = "${var.container_app_name}-env"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
}

# Container App
resource "azurerm_container_app" "app" {
  name                         = var.container_app_name
  container_app_environment_id = azurerm_container_app_environment.env.id
  resource_group_name          = azurerm_resource_group.rg.name
  revision_mode                = "Single"

  identity {
    type = "SystemAssigned"
  }

  template {
    container {
      name   = var.container_app_name
      image  = var.container_image
      cpu    = 0.25
      memory = "0.5Gi"

      env {
        name  = "DATABASE_HOST"
        value = azurerm_postgresql_flexible_server.postgres.fqdn
      }

      env {
        name  = "DATABASE_USER"
        value = var.postgres_admin
      }

      env {
        name  = "DATABASE_PASSWORD"
        value = var.postgres_password
      }
    }
  }
}