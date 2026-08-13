locals {
  breeze_shape         = "VM.Standard.E2.1.Micro"
  vscode_shape         = "VM.Standard.A1.Flex"
  vscode_ocpus         = 2
  vscode_memory_gb     = 12
  boot_volume_gb       = 50
  total_boot_volume_gb = local.boot_volume_gb * 2
  breeze_ad            = try(trimspace(var.breeze_availability_domain), "") != "" ? var.breeze_availability_domain : data.oci_identity_availability_domains.available.availability_domains[0].name
  vscode_ad            = try(trimspace(var.vscode_availability_domain), "") != "" ? var.vscode_availability_domain : data.oci_identity_availability_domains.available.availability_domains[0].name
  common_tags          = merge(var.freeform_tags, { Project = "oracle-breeze-infra", CostProfile = "AlwaysFree" })
}

data "oci_identity_availability_domains" "available" {
  compartment_id = var.tenancy_ocid
}

data "oci_core_images" "breeze_ubuntu" {
  compartment_id           = var.compartment_ocid
  operating_system         = "Canonical Ubuntu"
  operating_system_version = "22.04"
  shape                    = local.breeze_shape
  state                    = "AVAILABLE"
  sort_by                  = "TIMECREATED"
  sort_order               = "DESC"
}

data "oci_core_images" "vscode_ubuntu" {
  compartment_id           = var.compartment_ocid
  operating_system         = "Canonical Ubuntu"
  operating_system_version = "22.04"
  shape                    = local.vscode_shape
  state                    = "AVAILABLE"
  sort_by                  = "TIMECREATED"
  sort_order               = "DESC"
}

resource "oci_core_vcn" "breeze" {
  compartment_id = var.compartment_ocid
  cidr_blocks    = ["10.42.0.0/16"]
  display_name   = "oracle-breeze-vcn"
  dns_label      = "breezevcn"
  freeform_tags  = local.common_tags
}

resource "oci_core_internet_gateway" "breeze" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.breeze.id
  display_name   = "oracle-breeze-internet-gateway"
  enabled        = true
  freeform_tags  = local.common_tags
}

resource "oci_core_route_table" "public" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.breeze.id
  display_name   = "oracle-breeze-public-routes"
  freeform_tags  = local.common_tags

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_internet_gateway.breeze.id
  }
}

resource "oci_core_security_list" "hosts" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.breeze.id
  display_name   = "oracle-breeze-minimal-security-list"
  freeform_tags  = local.common_tags

  ingress_security_rules {
    protocol    = "6"
    source      = var.ssh_allowed_cidr
    source_type = "CIDR_BLOCK"
    description = "SSH to both hosts from one explicitly trusted IPv4 address"

    tcp_options {
      min = 22
      max = 22
    }
  }

  egress_security_rules {
    protocol         = "all"
    destination      = "0.0.0.0/0"
    destination_type = "CIDR_BLOCK"
    description      = "Outbound package, Tailscale, development, and Breeze API access"
  }
}

resource "oci_core_subnet" "public" {
  compartment_id             = var.compartment_ocid
  vcn_id                     = oci_core_vcn.breeze.id
  cidr_block                 = "10.42.1.0/24"
  display_name               = "oracle-breeze-public-subnet"
  dns_label                  = "public"
  prohibit_public_ip_on_vnic = false
  route_table_id             = oci_core_route_table.public.id
  security_list_ids          = [oci_core_security_list.hosts.id]
  freeform_tags              = local.common_tags
}

resource "oci_core_instance" "breeze_trading" {
  availability_domain = local.breeze_ad
  compartment_id      = var.compartment_ocid
  display_name        = "breeze-trading"
  shape               = local.breeze_shape
  freeform_tags       = merge(local.common_tags, { Role = "LiveTrading" })

  create_vnic_details {
    assign_public_ip = false
    display_name     = "breeze-trading-primary-vnic"
    hostname_label   = "breeze-trading"
    subnet_id        = oci_core_subnet.public.id
  }

  metadata = {
    ssh_authorized_keys = trimspace(var.ssh_authorized_key)
    user_data           = base64encode(file("${path.module}/../cloud-init/cloud-config.yaml"))
  }

  source_details {
    source_id               = data.oci_core_images.breeze_ubuntu.images[0].id
    source_type             = "image"
    boot_volume_size_in_gbs = local.boot_volume_gb
  }

  lifecycle {
    precondition {
      condition     = length(data.oci_core_images.breeze_ubuntu.images) > 0
      error_message = "No compatible Ubuntu 22.04 image was found for VM.Standard.E2.1.Micro in this region."
    }
  }
}

resource "oci_core_instance" "vscode_dev" {
  availability_domain = local.vscode_ad
  compartment_id      = var.compartment_ocid
  display_name        = "vscode-dev"
  shape               = local.vscode_shape
  freeform_tags       = merge(local.common_tags, { Role = "Development" })

  shape_config {
    ocpus         = local.vscode_ocpus
    memory_in_gbs = local.vscode_memory_gb
  }

  create_vnic_details {
    assign_public_ip = true
    display_name     = "vscode-dev-primary-vnic"
    hostname_label   = "vscode-dev"
    subnet_id        = oci_core_subnet.public.id
  }

  metadata = {
    ssh_authorized_keys = trimspace(var.ssh_authorized_key)
    user_data           = base64encode(file("${path.module}/../cloud-init/vscode-dev.yaml"))
  }

  source_details {
    source_id               = data.oci_core_images.vscode_ubuntu.images[0].id
    source_type             = "image"
    boot_volume_size_in_gbs = local.boot_volume_gb
  }

  lifecycle {
    precondition {
      condition     = length(data.oci_core_images.vscode_ubuntu.images) > 0
      error_message = "No compatible Ubuntu 22.04 ARM64 image was found for VM.Standard.A1.Flex in this region."
    }
  }
}

data "oci_core_vnic_attachments" "breeze_trading" {
  compartment_id = var.compartment_ocid
  instance_id    = oci_core_instance.breeze_trading.id
}

data "oci_core_vnic" "breeze_trading" {
  vnic_id = data.oci_core_vnic_attachments.breeze_trading.vnic_attachments[0].vnic_id
}

data "oci_core_private_ips" "breeze_trading" {
  vnic_id = data.oci_core_vnic.breeze_trading.id
}

resource "oci_core_public_ip" "breeze_trading" {
  compartment_id = var.compartment_ocid
  display_name   = "breeze-trading-reserved-ip"
  lifetime       = "RESERVED"
  private_ip_id  = data.oci_core_private_ips.breeze_trading.private_ips[0].id
  freeform_tags  = local.common_tags
}

data "oci_core_vnic_attachments" "vscode_dev" {
  compartment_id = var.compartment_ocid
  instance_id    = oci_core_instance.vscode_dev.id
}

data "oci_core_vnic" "vscode_dev" {
  vnic_id = data.oci_core_vnic_attachments.vscode_dev.vnic_attachments[0].vnic_id
}

check "always_free_guardrails" {
  assert {
    condition     = oci_core_instance.breeze_trading.shape == "VM.Standard.E2.1.Micro"
    error_message = "breeze-trading must use the Always Free VM.Standard.E2.1.Micro shape."
  }

  assert {
    condition     = oci_core_instance.vscode_dev.shape == "VM.Standard.A1.Flex"
    error_message = "vscode-dev must use the Always Free VM.Standard.A1.Flex shape."
  }

  assert {
    condition     = local.vscode_ocpus == 2 && local.vscode_memory_gb == 12
    error_message = "vscode-dev must remain at the Always Free allocation of 2 OCPUs and 12 GB RAM."
  }

  assert {
    condition     = local.total_boot_volume_gb == 100
    error_message = "The two boot volumes must remain at 50 GB each (100 GB total)."
  }

  assert {
    condition     = oci_core_public_ip.breeze_trading.lifetime == "RESERVED"
    error_message = "breeze-trading must retain a RESERVED public IPv4 address."
  }
}
