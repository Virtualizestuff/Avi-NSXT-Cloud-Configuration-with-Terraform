data "vsphere_content_library" "content_library" {
  name = var.content_library_name
}

data "nsxt_transport_zone" "nsxt_mgmt_tz_name" {
  display_name = var.nsxt_cloud_mgmt_tz_name
}

data "nsxt_transport_zone" "nsxt_data_tz_name" {
  display_name = var.nsxt_cloud_data_tz_name
}

data "avi_network" "avi_vip" {
  cloud_ref  = avi_cloud.nsxt_cloud.id
  name       = var.data_avi_network_avi_vip_name
  depends_on = [time_sleep.wait_20_seconds]
}

data "avi_applicationprofile" "system_dns" {
  name = var.data_avi_applicationprofile_system_dns_name
}

data "avi_ipamdnsproviderprofile" "nsxtcloud_ipamdnsproviderprofile" {
  name = var.avi_IPAM_profile_name
}