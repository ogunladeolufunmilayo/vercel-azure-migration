variable "location" {
  type    = string
  default = "canadacentral"
}

variable "resource_group_name" {
  type    = string
  default = "rg-vercel-azure-migration"
}

variable "app_name" {
  type    = string
  default = "vercel-azure-mig"
}

variable "database_url" {
  type      = string
  sensitive = true
}

variable "tags" {
  type    = map(string)
  default = { project = "vercel-azure-migration" }
}
