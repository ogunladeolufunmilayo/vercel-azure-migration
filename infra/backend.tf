terraform {
  backend "azurerm" {
    resource_group_name  = "terraform-state-rg"
    storage_account_name = "funmilayotfstate29073"
    container_name       = "tfstate"
    key                  = "vercel-azure-migration/terraform.tfstate"
    use_oidc             = true
  }
}
