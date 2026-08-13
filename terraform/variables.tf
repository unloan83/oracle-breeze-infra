variable "tenancy_ocid" {
  description = "OCI tenancy OCID. Set with TF_VAR_tenancy_ocid."
  type        = string
  sensitive   = true

  validation {
    condition     = can(regex("^ocid1\\.tenancy\\.", var.tenancy_ocid))
    error_message = "tenancy_ocid must be an OCI tenancy OCID."
  }
}

variable "user_ocid" {
  description = "OCI API user OCID. Set with TF_VAR_user_ocid."
  type        = string
  sensitive   = true

  validation {
    condition     = can(regex("^ocid1\\.user\\.", var.user_ocid))
    error_message = "user_ocid must be an OCI user OCID."
  }
}

variable "fingerprint" {
  description = "Fingerprint of the OCI API signing key."
  type        = string
  sensitive   = true

  validation {
    condition     = can(regex("^([0-9a-fA-F]{2}:){15}[0-9a-fA-F]{2}$", var.fingerprint))
    error_message = "fingerprint must contain 16 colon-separated hexadecimal byte pairs."
  }
}

variable "private_key_path" {
  description = "Path to the OCI API private key; never commit the key."
  type        = string
  sensitive   = true
}

variable "region" {
  description = "OCI home region identifier, for example ap-mumbai-1."
  type        = string

  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-[0-9]+$", var.region))
    error_message = "region must be an OCI region identifier such as ap-mumbai-1."
  }
}

variable "compartment_ocid" {
  description = "OCID of the compartment in which resources will be created."
  type        = string

  validation {
    condition     = can(regex("^ocid1\\.compartment\\.", var.compartment_ocid)) || can(regex("^ocid1\\.tenancy\\.", var.compartment_ocid))
    error_message = "compartment_ocid must be an OCI compartment or tenancy OCID."
  }
}

variable "ssh_authorized_key" {
  description = "Public SSH key installed for the Ubuntu user."
  type        = string
  sensitive   = true

  validation {
    condition     = can(regex("^(ssh-(rsa|ed25519)|ecdsa-sha2-nistp(256|384|521)) [A-Za-z0-9+/]+={0,3}( .*)?$", trimspace(var.ssh_authorized_key))) && !can(regex("PRIVATE KEY", var.ssh_authorized_key))
    error_message = "ssh_authorized_key must be a valid OpenSSH public key (never provide a private key)."
  }
}

variable "ssh_allowed_cidr" {
  description = "Single trusted public IPv4 address in /32 notation allowed to SSH."
  type        = string

  validation {
    condition     = can(cidrnetmask(var.ssh_allowed_cidr)) && can(regex("^([0-9]{1,3}\\.){3}[0-9]{1,3}/32$", var.ssh_allowed_cidr)) && var.ssh_allowed_cidr != "0.0.0.0/32"
    error_message = "ssh_allowed_cidr must be one trusted public IPv4 address in /32 notation."
  }
}

variable "breeze_availability_domain" {
  description = "Optional AD for breeze-trading. Leave null to use the first AD."
  type        = string
  default     = null
  nullable    = true
}

variable "vscode_availability_domain" {
  description = "Optional AD for vscode-dev. Leave null to use the first AD."
  type        = string
  default     = null
  nullable    = true
}

variable "confirm_home_region" {
  description = "Safety acknowledgement that region is the tenancy home region, required for Always Free compute and block storage."
  type        = bool
  default     = false

  validation {
    condition     = var.confirm_home_region
    error_message = "Set confirm_home_region=true only after verifying that region is the OCI tenancy home region."
  }
}

variable "freeform_tags" {
  description = "Optional non-sensitive free-form tags."
  type        = map(string)
  default     = {}
}
