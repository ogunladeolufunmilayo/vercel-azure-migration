output "webapp_url" {
  value = "https://${azurerm_linux_web_app.app.default_hostname}"
}
output "resource_group_name" {
  value = azurerm_resource_group.rg.name
}
output "key_vault_name" {
  value = azurerm_key_vault.kv.name
}
