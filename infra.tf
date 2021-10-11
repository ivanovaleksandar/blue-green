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
variable "region" {
  default = "europe-west4"
}
variable "zone" {
  default = "a"
}

data "google_client_config" "default" {}
data "google_project" "project" {}

resource "google_storage_bucket_iam_member" "registry" {
  bucket = "eu.artifacts.${var.project_id}.appspot.com"
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${data.google_project.project.number}-compute@developer.gserviceaccount.com"
}

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

  node_config {
    machine_type = "n2-standard-2"
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
  }
}


resource "google_compute_address" "regional_lb_ip" {
  name   = "lb"
  region = var.region
}

# resource "kubernetes_namespace" "nginx" {
#   metadata {
#     name = "nginx"
#   }
# }

# resource "helm_release" "nginx" {
#   name       = "nginx"
#   repository = "https://kubernetes.github.io/ingress-nginx"
#   chart      = "ingress-nginx"
#   version    = "4.0.5"
#   namespace  = kubernetes_namespace.nginx.metadata[0].name

#   set {
#     name  = "controller.service.loadBalancerIP"
#     value = google_compute_address.regional_lb_ip.address
#   }

#   depends_on = [google_container_cluster.gke]
# }

output "location" {
  value = "${var.region}-${var.zone}"
}

output "gke_name" {
  value = google_container_cluster.gke.name
}

output "lb_address" {
  value = google_compute_address.regional_lb_ip.address
}
