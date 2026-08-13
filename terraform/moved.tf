# Preserve existing resources when upgrading from the original single-VM
# configuration. These declarations are harmless for a fresh deployment.
moved {
  from = oci_core_security_list.trading
  to   = oci_core_security_list.hosts
}

moved {
  from = oci_core_instance.trading
  to   = oci_core_instance.breeze_trading
}

moved {
  from = oci_core_public_ip.reserved
  to   = oci_core_public_ip.breeze_trading
}
