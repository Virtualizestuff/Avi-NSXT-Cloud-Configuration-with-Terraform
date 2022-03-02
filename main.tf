terraform {
  required_version = ">= 0.13.6"

  required_providers {
    avi = {
      source = "vmware/avi"
      version = "21.1.3"
    }
    vsphere = {
      source = "hashicorp/vsphere"
    }
    nsxt = {
      source = "vmware/nsxt"
      version = "3.2.5"
    }
    time = {
      source = "hashicorp/time"
      version = "0.7.2"
    }
  }
}

provider "avi" {
  avi_username   = var.avi_username
  avi_password   = var.avi_password
  avi_controller = var.avi_controller
  avi_tenant     = var.tenant
  avi_version    = var.avi_version
}

provider "vsphere"{
  user = var.vsphere_user
  password = var.vsphere_password
  vsphere_server = var.vsphere_server
  allow_unverified_ssl = true
}

provider "nsxt"{
  host = var.nsxt_cloud_url
  username = var.nsxt_cloud_username
  password = var.nsxt_cloud_password
  allow_unverified_ssl = true
}

provider "time" {
  # Configuration options
}