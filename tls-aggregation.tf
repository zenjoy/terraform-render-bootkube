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

# Kubernetes Aggregation CA (tls/{aggregation-ca.crt,aggregation-ca.key})
resource "tls_private_key" "kube-aggregation-ca" {
  count = var.aggregation_ca_certificate == "" ? 1 : 0

  algorithm = "RSA"
  rsa_bits  = "2048"
}

resource "tls_self_signed_cert" "kube-aggregation-ca" {
  count = var.aggregation_ca_certificate == "" ? 1 : 0

  key_algorithm   = tls_private_key.kube-aggregation-ca[0].algorithm
  private_key_pem = tls_private_key.kube-aggregation-ca[0].private_key_pem

  subject {
    common_name  = "kube-aggregation-ca"
    organization = "bootkube"
  }

  is_ca_certificate     = true
  validity_period_hours = var.cacert_validity_hours

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "cert_signing",
  ]
}

resource "local_file" "kube-aggregation-ca-key" {
  content  = join(" ", tls_private_key.kube-aggregation-ca.*.private_key_pem)
  filename = "${var.asset_dir}/tls/aggregation-ca.key"
}

resource "local_file" "kube-aggregation-ca-crt" {
  content  = join(" ", tls_self_signed_cert.kube-ca.*.cert_pem)
  filename = "${var.asset_dir}/tls/aggregation-ca.crt"
}

# Kubernetes API Server (tls/{aggregation-apiserver.key,aggregation-apiserver.crt})
resource "tls_private_key" "aggregation-apiserver" {
  algorithm = "RSA"
  rsa_bits  = "2048"
}

resource "tls_cert_request" "aggregation-apiserver" {
  key_algorithm   = tls_private_key.aggregation-apiserver.algorithm
  private_key_pem = tls_private_key.aggregation-apiserver.private_key_pem

  subject {
    common_name  = "front-proxy-client"
    organization = "system:masters"
  }

  dns_names = concat(
    compact([var.api_server_altname]),
    var.api_servers,
    list(
      "kubernetes",
      "kubernetes.default",
      "kubernetes.default.svc",
      "kubernetes.default.svc.${var.cluster_domain_suffix}"
    )
  )

  ip_addresses = [
    cidrhost(var.service_cidr, 1),
  ]
}

resource "tls_locally_signed_cert" "aggregation-apiserver" {
  cert_request_pem = tls_cert_request.aggregation-apiserver.cert_request_pem

  ca_key_algorithm   = join(" ", tls_self_signed_cert.kube-aggregation-ca.*.key_algorithm)
  ca_private_key_pem = join(" ", tls_private_key.kube-aggregation-ca.*.private_key_pem)
  ca_cert_pem        = join(" ", tls_self_signed_cert.kube-aggregation-ca.*.cert_pem)

  validity_period_hours = var.cert_validity_hours

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
    "client_auth",
  ]
}

resource "local_file" "aggregation-apiserver-key" {
  content  = tls_private_key.aggregation-apiserver.private_key_pem
  filename = "${var.asset_dir}/tls/aggregation-apiserver.key"
}

resource "local_file" "aggregation-apiserver-crt" {
  content  = tls_locally_signed_cert.aggregation-apiserver.cert_pem
  filename = "${var.asset_dir}/tls/aggregation-apiserver.crt"
}
