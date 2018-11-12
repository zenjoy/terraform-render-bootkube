# NOTE: Across this module, the following syntax is used at various places:
#   `"${var.ca_certificate == "" ? join(" ", tls_private_key.kube-ca.*.private_key_pem) : var.ca_private_key}"`
#
# Due to https://github.com/hashicorp/hil/issues/50, both sides of conditions
# are evaluated, until one of them is discarded. Unfortunately, the
# `{tls_private_key/tls_self_signed_cert}.kube-ca` resources are created
# conditionally and might not be present - in which case an error is
# generated. Because a `count` is used on these ressources, the resources can be
# referenced as lists with the `.*` notation, and arrays are allowed to be
# empty. The `join()` interpolation function is then used to cast them back to
# a string. Since `count` can only be 0 or 1, the returned value is either empty
# (and discarded anyways) or the desired value.

# Kubernetes CA (tls/{ca.crt,ca.key})
resource "tls_private_key" "kube-ca" {
  count = "${var.ca_certificate == "" ? 1 : 0}"

  algorithm = "RSA"
  rsa_bits  = "2048"
}

resource "tls_self_signed_cert" "kube-ca" {
  count = "${var.ca_certificate == "" ? 1 : 0}"

  key_algorithm   = "${tls_private_key.kube-ca.algorithm}"
  private_key_pem = "${tls_private_key.kube-ca.private_key_pem}"

  subject {
    common_name  = "kube-ca"
    organization = "bootkube"
  }

  is_ca_certificate     = true
  validity_period_hours = 8760

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "cert_signing",
  ]
}

resource "local_file" "kube-ca-key" {
  content  = "${var.ca_certificate == "" ? join(" ", tls_private_key.kube-ca.*.private_key_pem) : var.ca_private_key}"
  filename = "${var.asset_dir}/tls/ca.key"
}

resource "local_file" "kube-ca-crt" {
  content  = "${var.ca_certificate == "" ? join(" ", tls_self_signed_cert.kube-ca.*.cert_pem) : var.ca_certificate}"
  filename = "${var.asset_dir}/tls/ca.crt"
}

# Kubernetes API Server (tls/{apiserver.key,apiserver.crt})
resource "tls_private_key" "apiserver" {
  algorithm = "RSA"
  rsa_bits  = "2048"
}

resource "tls_cert_request" "apiserver" {
  key_algorithm   = "${tls_private_key.apiserver.algorithm}"
  private_key_pem = "${tls_private_key.apiserver.private_key_pem}"

  subject {
    common_name  = "kube-apiserver"
    organization = "system:masters"
  }

  dns_names = [
    "${compact(list(var.api_server_altname))}",
    "${compact(list(var.internal_api_server_altname))}",
    "${var.api_servers}",
    "kubernetes",
    "kubernetes.default",
    "kubernetes.default.svc",
    "kubernetes.default.svc.${var.cluster_domain_suffix}",
  ]

  ip_addresses = [
    "${cidrhost(var.service_cidr, 1)}",
  ]
}

resource "tls_locally_signed_cert" "apiserver" {
  cert_request_pem = "${tls_cert_request.apiserver.cert_request_pem}"

  ca_key_algorithm   = "${var.ca_certificate == "" ? join(" ", tls_self_signed_cert.kube-ca.*.key_algorithm) : var.ca_key_alg}"
  ca_private_key_pem = "${var.ca_certificate == "" ? join(" ", tls_private_key.kube-ca.*.private_key_pem) : var.ca_private_key}"
  ca_cert_pem        = "${var.ca_certificate == "" ? join(" ", tls_self_signed_cert.kube-ca.*.cert_pem): var.ca_certificate}"

  validity_period_hours = 8760

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
    "client_auth",
  ]
}

resource "local_file" "apiserver-key" {
  content  = "${tls_private_key.apiserver.private_key_pem}"
  filename = "${var.asset_dir}/tls/apiserver.key"
}

resource "local_file" "apiserver-crt" {
  content  = "${tls_locally_signed_cert.apiserver.cert_pem}"
  filename = "${var.asset_dir}/tls/apiserver.crt"
}

# Kubernete's Service Account (tls/{service-account.key,service-account.pub})
resource "tls_private_key" "service-account" {
  algorithm = "RSA"
  rsa_bits  = "2048"
}

resource "local_file" "service-account-key" {
  content  = "${tls_private_key.service-account.private_key_pem}"
  filename = "${var.asset_dir}/tls/service-account.key"
}

resource "local_file" "service-account-crt" {
  content  = "${tls_private_key.service-account.public_key_pem}"
  filename = "${var.asset_dir}/tls/service-account.pub"
}

# Kubelet
resource "tls_private_key" "kubelet" {
  algorithm = "RSA"
  rsa_bits  = "2048"
}

resource "tls_cert_request" "kubelet" {
  key_algorithm   = "${tls_private_key.kubelet.algorithm}"
  private_key_pem = "${tls_private_key.kubelet.private_key_pem}"

  subject {
    common_name  = "kubelet"
    organization = "system:masters"
  }
}

resource "tls_locally_signed_cert" "kubelet" {
  cert_request_pem = "${tls_cert_request.kubelet.cert_request_pem}"

  ca_key_algorithm   = "${var.ca_certificate == "" ? join(" ", tls_self_signed_cert.kube-ca.*.key_algorithm) : var.ca_key_alg}"
  ca_private_key_pem = "${var.ca_certificate == "" ? join(" ", tls_private_key.kube-ca.*.private_key_pem) : var.ca_private_key}"
  ca_cert_pem        = "${var.ca_certificate == "" ? join(" ", tls_self_signed_cert.kube-ca.*.cert_pem) : var.ca_certificate}"

  validity_period_hours = 8760

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
    "client_auth",
  ]
}

resource "local_file" "kubelet-key" {
  content  = "${tls_private_key.kubelet.private_key_pem}"
  filename = "${var.asset_dir}/tls/kubelet.key"
}

resource "local_file" "kubelet-crt" {
  content  = "${tls_locally_signed_cert.kubelet.cert_pem}"
  filename = "${var.asset_dir}/tls/kubelet.crt"
}
