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

# Subnet conteneur app
resource "azurerm_subnet" "container_subnet" {
  name                 = "container-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
  
  delegation {
      name = "containerapps-delegation"
 
      service_delegation {
         name = "Microsoft.App/environments"
 
         actions = [
           "Microsoft.Network/virtualNetworks/subnets/join/action",
         ]
      }
   }
}

# Postgres subnet 
resource "azurerm_subnet" "subnet" {
  name                 = var.subnet_name
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.2.0/24"]

  delegation {
    name = "postgres-delegation"

    service_delegation {
      name = "Microsoft.DBforPostgreSQL/flexibleServers"

      actions = [
        "Microsoft.Network/virtualNetworks/subnets/join/action",
      ]
    }
  }
}

resource "azurerm_private_dns_zone" "dns" {
  name                = "privatelink.postgres.database.azure.com"
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "dns_link" {
  name                  = "dns-link"
  resource_group_name   = azurerm_resource_group.rg.name
  private_dns_zone_name = azurerm_private_dns_zone.dns.name
  virtual_network_id    = azurerm_virtual_network.vnet.id
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
  private_dns_zone_id           = azurerm_private_dns_zone.dns.id
  public_network_access_enabled = false
  sku_name                      = "B_Standard_B1ms"
}

# Container App Environment
resource "azurerm_container_app_environment" "env" {
  name                     = "${var.container_app_name}-env"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  infrastructure_subnet_id = azurerm_subnet.container_subnet.id
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
      cpu    = 0.5
      memory = "1.0Gi"

      env {
        name  = "DATABASE_URL"
        value = "postgres://${var.postgres_admin}:${var.postgres_password}@${azurerm_postgresql_flexible_server.postgres.fqdn}:5432/postgres"
      }
    }
  }

  ingress {
    external_enabled = true
    target_port      = 3000

    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
  }
}
