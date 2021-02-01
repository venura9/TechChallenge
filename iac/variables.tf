variable "app-name" {
  type    = string
}

variable "app-location" {
  type    = string
  default = "australiaeast"
}

variable "subscription_id" {
  type = string
}

variable "client_id" {
  type = string
}

variable "client_secret" {
  type = string
  sensitive = true
}

variable "tenant_id" {
  type = string
}

variable "db_user" {
  type = string
}

variable "db_password" {
  type = string
  sensitive = true
}