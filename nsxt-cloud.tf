# Credential used to authenticate to NSX-T
resource "avi_cloudconnectoruser" "nsxt_cred" {
  name = var.nsxt_cloud_cred_name
  tenant_ref = var.tenant
  nsxt_credentials {
    username = var.nsxt_cloud_username
    password = var.nsxt_cloud_password
  }
}

# Credential used to authenticate to vCenter
resource "avi_cloudconnectoruser" "vcsa_cred" {
  name = var.vcsa_cred_name
  tenant_ref = var.tenant
  vcenter_credentials {
    username = var.vsphere_user
    password = var.vsphere_password
  }
}

# Create Avi Internal DNS Profile
resource "avi_ipamdnsproviderprofile" "avi_DNS" {
  name = var.avi_DNS_profile_name
  tenant_ref = var.tenant
  type = "IPAMDNS_TYPE_INTERNAL_DNS"
  internal_profile {
    dns_service_domain {
      domain_name = var.avi_DNS_profile_domain_name
    }
  }
}

# Create NSX-T Cloud
resource "avi_cloud" "nsxt_cloud" {
  name = var.cloud_name
  tenant_ref = var.tenant
  vtype = "CLOUD_NSXT"
  dhcp_enabled = true
  obj_name_prefix = var.nsxt_cloud_prefix
  dns_provider_ref = avi_ipamdnsproviderprofile.avi_DNS.id
  #ipam_provider_ref = avi_ipamdnsproviderprofile.avi_IPAM.id
  nsxt_configuration {
      nsxt_credentials_ref = avi_cloudconnectoruser.nsxt_cred.uuid
      nsxt_url = var.nsxt_cloud_url
      management_network_config {
      tz_type = var.nsxt_cloud_mgmt_tz_type
      transport_zone = "/infra/sites/default/enforcement-points/default/transport-zones/${data.nsxt_transport_zone.nsxt_mgmt_tz_name.id}"
      vlan_segment = "/infra/segments/${var.nsxt_cloud_vlan_seg}"
    }
    data_network_config {
      tz_type = var.nsxt_cloud_data_tz_type
      transport_zone = "/infra/sites/default/enforcement-points/default/transport-zones/${data.nsxt_transport_zone.nsxt_data_tz_name.id}"
      tier1_segment_config {
          segment_config_mode = "TIER1_SEGMENT_MANUAL"
          manual {
            tier1_lrs {
              tier1_lr_id = "/infra/tier-1s/${var.nsxt_cloud_lr1}"
              segment_id = "/infra/segments/${var.nsxt_cloud_overlay_seg}"
            }
          }
      }
    }
  }
}

# Associate vCenter & Content Library to NSX-T Cloud
resource "avi_vcenterserver" "vcenter_server" {
    name = var.nsxt_cloud_vcenter_name
    tenant_ref = var.tenant
    cloud_ref = avi_cloud.nsxt_cloud.id
    vcenter_url = var.vsphere_server
    content_lib {
      id = data.vsphere_content_library.content_library.id
    }
    vcenter_credentials_ref = avi_cloudconnectoruser.vcsa_cred.uuid
}

# This allows enough time to pass in order to do a data.avi_network.avi_vip collection.
# data.avi_network.avi_vip is depends_on the time_sleep.wait_20_seconds
resource "time_sleep" "wait_20_seconds" {
  depends_on = [avi_cloud.nsxt_cloud]
  create_duration = "20s"
}

# Create Empty Avi Internal IPAM Profile
resource "avi_ipamdnsproviderprofile" "avi_IPAM" {
  name = var.avi_IPAM_profile_name
  tenant_ref = var.tenant
  type = "IPAMDNS_TYPE_INTERNAL"
  internal_profile {
    usable_networks {
      nw_ref = data.avi_network.avi_vip.id
    }
  }
}

# Create IP Pool for Avi VIP Network
resource "avi_network" "avi_vip_network" {
  cloud_ref = avi_cloud.nsxt_cloud.id
  name = data.avi_network.avi_vip.name
  vrf_context_ref = data.avi_network.avi_vip.vrf_context_ref
  configured_subnets {
    prefix {
      ip_addr {
          addr = var.nsxt_cloud_vip_subnet
          type = "V4"      
      }
      mask = var.nsxt_cloud_vip_subnet_mask
    }
    static_ip_ranges {
      range {
        begin {
          addr = var.nsxt_cloud_vip_subnet_pool_begin
          type = "V4"   
        }
        end {
          addr = var.nsxt_cloud_vip_subnet_pool_end
          type = "V4"
        }
      }
      type = "STATIC_IPS_FOR_VIP_AND_SE"
    }
  }
  # The below attribute prevents Avi NSX-T Cloud from recreating a new network Avi-VIP
  attrs {
    key = "segmentid"
    value = "/infra/segments/Avi-VIP"
  }
  attrs {
    key = "autocreated"
    value = "nsxtcloud"
  }
  attrs {
    key = "cloudnetworkmode"
    value = "dhcp"
  }
}

# Create Default Static Route for VIP Network
resource "avi_vrfcontext" "default_static_route" {
  name = var.nsxt_cloud_lr1
  cloud_ref = avi_cloud.nsxt_cloud.id
  static_routes {
    prefix {
      ip_addr {
        addr = var.nsxt_cloud_vip_static_route_gateway_subnet
        type = "V4"      
      }
      mask = var.nsxt_cloud_vip_static_route_gateway_subnet_mask
    }
    next_hop {
      addr = var.nsxt_cloud_vip_static_route_next_hop
      type = "V4"      
    }
    route_id = "1"
  }
  attrs {
    key = "tier1path"
    value = "/infra/tier-1s/${var.nsxt_cloud_lr1}"
  }
}

# Create VIP for DNS VS
resource "avi_vsvip" "dns_vip" {
  name = var.dns_vip_name
  vip {
    vip_id = "1"
    ip_address {
      addr = var.vs_vip_static_address
      type = "V4"
    }
    enabled = true
  }
  tier1_lr = var.nsxt_cloud_lr1
  cloud_ref = avi_cloud.nsxt_cloud.id
  tenant_ref = var.tenant
  vrf_context_ref = data.avi_network.avi_vip.vrf_context_ref
}

# Create an Avi DNS Virtual Service
resource "avi_virtualservice" "dns" {
  name = var.vs_name
  enabled = false
  tenant_ref = var.tenant
  vsvip_ref = avi_vsvip.dns_vip.id
  cloud_ref = avi_cloud.nsxt_cloud.id
  application_profile_ref = data.avi_applicationprofile.system_dns.id
  vrf_context_ref = data.avi_network.avi_vip.vrf_context_ref
  services {
    port = var.vs_port
  }
}