terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "3.87.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.5.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "2.3.0"
    }
  }

  required_version = "~> 1.0.0"
}

provider "google" {
  project = var.project_id
  region  = var.region
}

variable "project_id" {}
variable "region" {}
variable "zone" {}
variable "git_repo" {}

data "google_client_config" "default" {}

resource "google_compute_network" "vpc" {
  name                    = "${var.project_id}-vpc"
  auto_create_subnetworks = "false"
}

resource "google_compute_subnetwork" "subnet" {
  name          = "${var.project_id}-subnet"
  region        = var.region
  network       = google_compute_network.vpc.name
  ip_cidr_range = "10.10.0.0/24"
}


resource "google_container_cluster" "gke" {
  name                     = "${var.project_id}-gke"
  location                 = "${var.region}-${var.zone}"
  remove_default_node_pool = false
  initial_node_count       = 1

  network    = google_compute_network.vpc.name
  subnetwork = google_compute_subnetwork.subnet.name
}

provider "kubernetes" {
  host                   = "https://${google_container_cluster.gke.endpoint}"
  token                  = data.google_client_config.default.access_token
  cluster_ca_certificate = base64decode(google_container_cluster.gke.master_auth[0].cluster_ca_certificate)
}

provider "helm" {
  kubernetes {
    host  = "https://${google_container_cluster.gke.endpoint}"
    token = data.google_client_config.default.access_token
    # client_certificate     = data.template_file.client_certificate.rendered
    # client_key             = data.template_file.client_key.rendered
    cluster_ca_certificate = base64decode(google_container_cluster.gke.master_auth[0].cluster_ca_certificate)
  }
}

resource "google_compute_address" "regional_lb_ip" {
  name   = "lb"
  region = var.region
}

resource "kubernetes_namespace" "nginx" {
  metadata {
    name = "nginx"
  }
}

resource "helm_release" "nginx" {
  name       = "nginx"
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"
  version    = "4.0.5"
  namespace  = kubernetes_namespace.nginx.metadata[0].name

  set {
    name  = "controller.service.loadBalancerIP"
    value = google_compute_address.regional_lb_ip.address
  }

}

resource "kubernetes_namespace" "flux" {
  metadata {
    name = "flux"
  }
}

resource "helm_release" "flux" {
  name       = "flux"
  repository = "https://charts.fluxcd.io"
  chart      = "flux"
  version    = "1.11.2"
  namespace  = kubernetes_namespace.flux.metadata[0].name

  set {
    name  = "git.url"
    value = "git@github.com:${var.git_repo}"
  }
}

resource "helm_release" "helm_operator" {
  name       = "helm-operator"
  repository = "https://charts.fluxcd.io"
  chart      = "helm-operator"
  version    = "1.4.0"
  namespace  = kubernetes_namespace.flux.metadata[0].name

  set {
    name  = "createCRD"
    value = false
  }
  set {
    name  = "helm.versions"
    value = "v3"
  }
  set {
    name  = "git.ssh.secretName"
    value = "flux-git-deploy"
  }
}