locals {
  name_prefix = var.app_name
}

data "azurerm_client_config" "current" {}

# ----------------------------
# Resource Group
# ----------------------------
resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

# ----------------------------
# Networking: VNet + delegated Subnet (for App Service VNet Integration)
# ----------------------------
resource "azurerm_virtual_network" "vnet" {
  name                = "${local.name_prefix}-vnet"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = ["10.20.0.0/16"]
  tags                = var.tags
}

resource "azurerm_subnet" "appsvc" {
  name                 = "${local.name_prefix}-snet-appsvc"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.20.1.0/24"]

  delegation {
    name = "delegation-appservice"
    service_delegation {
      name    = "Microsoft.Web/serverFarms"
      actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
    }
  }
}

# ----------------------------
# Application Insights
# ----------------------------
resource "azurerm_application_insights" "ai" {
  name                = "${local.name_prefix}-appi"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  application_type    = "web"
  tags                = var.tags
}

# ----------------------------
# App Service Plan + Linux Web App
# ----------------------------
resource "azurerm_service_plan" "plan" {
  name                = "${local.name_prefix}-plan"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  os_type             = "Linux"
  sku_name            = "B1"
  tags                = var.tags
}

# ----------------------------
# Key Vault + Secret (DATABASE_URL)
# ----------------------------
resource "azurerm_key_vault" "kv" {
  name                       = "${local.name_prefix}-kv"
  location                   = azurerm_resource_group.rg.location
  resource_group_name        = azurerm_resource_group.rg.name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  enable_rbac_authorization  = true
  soft_delete_retention_days = 7
  purge_protection_enabled   = false
  tags                       = var.tags
}

# Allow the identity running Terraform to manage Key Vault (create secrets, etc.)
resource "azurerm_role_assignment" "kv_admin_current" {
  scope                = azurerm_key_vault.kv.id
  role_definition_name = "Key Vault Administrator"
  principal_id         = data.azurerm_client_config.current.object_id
}

resource "azurerm_key_vault_secret" "database_url" {
  name         = "DATABASE-URL"
  value        = var.database_url
  key_vault_id = azurerm_key_vault.kv.id

  depends_on = [azurerm_role_assignment.kv_admin_current]
}

# ----------------------------
# Linux Web App (with System Assigned Identity)
# - DATABASE_URL is a Key Vault reference (no secret stored in App Service)
# ----------------------------
resource "azurerm_linux_web_app" "app" {
  name                = "${local.name_prefix}-web"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  service_plan_id     = azurerm_service_plan.plan.id
  https_only          = true

  identity {
    type = "SystemAssigned"
  }

  site_config {
    always_on  = true
    ftps_state = "Disabled"

    application_stack {
      node_version = "20-lts"
    }
  }

  app_settings = {
    "SCM_DO_BUILD_DURING_DEPLOYMENT"             = "true"
    "WEBSITE_NODE_DEFAULT_VERSION"               = "20.0"
    "APPLICATIONINSIGHTS_CONNECTION_STRING"      = azurerm_application_insights.ai.connection_string
    "APPINSIGHTS_INSTRUMENTATIONKEY"             = azurerm_application_insights.ai.instrumentation_key
    "ApplicationInsightsAgent_EXTENSION_VERSION" = "~3"

    # Key Vault reference (versionless so rotation won't break)
    "DATABASE_URL" = "@Microsoft.KeyVault(SecretUri=${azurerm_key_vault_secret.database_url.versionless_id})"
  }

  tags = var.tags

  # Ensure secret exists before we set the reference
  depends_on = [azurerm_key_vault_secret.database_url]
}

# Allow the Web App identity to read secrets
resource "azurerm_role_assignment" "kv_secrets_user_app" {
  scope                = azurerm_key_vault.kv.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_linux_web_app.app.identity[0].principal_id
}

# ----------------------------
# VNet Integration (Swift)
# ----------------------------
resource "azurerm_app_service_virtual_network_swift_connection" "vnet_integration" {
  app_service_id = azurerm_linux_web_app.app.id
  subnet_id      = azurerm_subnet.appsvc.id

  depends_on = [azurerm_linux_web_app.app]
}
