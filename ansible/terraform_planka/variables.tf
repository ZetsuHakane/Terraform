# Les variables utiles pour la création des ressources

variable "resource_group_name" {}
variable "location" { type = string }
variable "vnet_name" { type = string }
variable "subnet_name" { type = string }
variable "postgres_name" { type = string }
variable "postgres_admin" { type = string }
variable "postgres_password" { type = string }
variable "container_app_name" { type = string }
variable "container_image" { type = string }