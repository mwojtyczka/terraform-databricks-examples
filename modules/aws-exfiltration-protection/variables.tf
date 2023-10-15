variable "databricks_account_username" {}
variable "databricks_account_password" {}
variable "databricks_account_id" {}

variable "tags" {
  default = {}
}

variable "spoke_cidr_block" {
  default = "10.173.0.0/16"
}

variable "hub_cidr_block" {
  default = "10.10.0.0/16"
}

variable "region" {
  default = "eu-central-1"
}

resource "random_string" "naming" {
  special = false
  upper   = false
  length  = 6
}

variable "whitelisted_urls" {
  default = [".pypi.org", ".pythonhosted.org", ".cran.r-project.org"]
}

variable "db_web_app" {
  default = null # will use predefined for the region if not provided
  description = "Webapp address that corresponds to the cloud region"
}

variable "db_tunnel" {
  default = null # will use predefined for the region if not provided
  description = "SCC relay address that corresponds to the cloud region"
}

variable "db_rds" {
  default = null # will use predefined for the region if not provided
  description = "RDS address for legacy Hive metastore that corresponds to the cloud region"
}

variable "db_control_plane" {
  default = null # will use predefined for the region if not provided
  description = "Control plane infrastructure address that corresponds to the cloud region"
}

variable "prefix" {
  default = "demo"
}