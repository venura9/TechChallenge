variable "app-name" {
  type = string
}

variable "db_password" {
  type      = string
  sensitive = true
}

variable "app-location" {
  type    = string
  default = "australiaeast"
}

variable "db_user" {
  type = string
}

variable "container_scope" {
  type      = string
  default = "todoapp"
}