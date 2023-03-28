resource "google_compute_network" "example" {
  name                    = "example-network"
  auto_create_subnetworks = false
  project                 = var.project_id
}

resource "google_compute_subnetwork" "example" {
  name          = "example-subnetwork"
  ip_cidr_range = "10.2.0.0/16"
  region        = "us-central1"
  network       = google_compute_network.example.id
  project       = var.project_id
}

resource "google_compute_router" "example" {
  name    = "example-router"
  region  = google_compute_subnetwork.example.region
  network = google_compute_network.example.id

  bgp {
    asn = 64514
  }
  project = var.project_id
}

resource "google_compute_router_nat" "example" {
  name                               = "example-nat"
  router                             = google_compute_router.example.name
  region                             = google_compute_router.example.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
  project = var.project_id
}

resource "google_compute_route" "public_internet" {
  network          = google_compute_network.default.id
  name             = "${google_compute_network.default.name}-public-internet"
  description      = "Custom static route to communicate with the public internet"
  dest_range       = "0.0.0.0/0"
  next_hop_gateway = "default-internet-gateway"
  priority         = 1000
  project          = var.project_id
}
