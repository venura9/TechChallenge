variable "app-name" {
  type = string
}

variable "db-password" {
  type      = string
  sensitive = true
}

variable "app-location" {
  type    = string
  default = "australiaeast"
}

variable "db-user" {
  type = string
}

# variable "container_scope" {
#   type      = string
#   default = "todoapp"
# }

variable "environment" {
  type    = string
  default = "prd"
}