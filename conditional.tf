# Assets generated only when certain options are chosen

resource "template_dir" "flannel-manifests" {
  count           = var.networking == "flannel" ? 1 : 0
  source_dir      = "bootkube/resources/flannel"
  destination_dir = "${var.asset_dir}/manifests-networking"

  vars = {
    flannel_image     = var.container_images["flannel"]
    flannel_cni_image = var.container_images["flannel_cni"]
    pod_cidr          = var.pod_cidr
  }
}

resource "template_dir" "calico-manifests" {
  count           = var.networking == "calico" ? 1 : 0
  source_dir      = "bootkube/resources/calico"
  destination_dir = "${var.asset_dir}/manifests-networking"

  vars = {
    calico_image                    = var.container_images["calico"]
    calico_cni_image                = var.container_images["calico_cni"]
    network_mtu                     = var.network_mtu
    network_ip_autodetection_method = var.network_ip_autodetection_method
    pod_cidr                        = var.pod_cidr
  }
}

resource "template_dir" "weave-manifests" {
  count           = var.networking == "weave" ? 1 : 0
  source_dir      = "bootkube/resources/weave"
  destination_dir = "${var.asset_dir}/manifests-networking"

  vars = {
    weave_kube_image = var.container_images["weave_kube"]
    weave_npc_image  = var.container_images["weave_npc"]
    pod_cidr         = var.pod_cidr
    weave_passwd     = random_string.weave_passwd[0].result
  }
}

resource "random_string" "weave_passwd" {
  count  = var.networking == "weave" ? 1 : 0
  length = 32
}

