# Managed Ubuntu Cloud source image for the VM
data "google_compute_image" "ubuntu" {
  family  = "ubuntu-2004-lts"
  project = "ubuntu-os-cloud"
}

# Create a service account for the VM
resource "google_service_account" "gha_runners" {
  account_id   = "gha-runners"
  display_name = "Service Account for GitHub Actions Runners"
  project      = var.project_id
}

# Required to write logs to Cloud Logging
resource "google_project_iam_member" "gha_runners_log_writer" {
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.gha_runners.email}"
  project = var.project_id
}

# Required to write logs to Cloud Logging
resource "google_project_iam_member" "gha_runners_metric_writer" {
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.gha_runners.email}"
  project = var.project_id
}

# Grant the service account associated to the VM access to the secret
resource "google_secret_manager_secret_iam_member" "gha_runners_github_runner_org_token_secret_accessor" {
  secret_id = google_secret_manager_secret.github_runner_org_token.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.gha_runners.email}"
  project   = google_secret_manager_secret.github_runner_org_token.project
}

# Blueprint for the VM
resource "google_compute_instance_template" "gha_runners" {
  name_prefix          = "gha-runner"
  description          = "This template is used to create VMs that run GitHub Actions Runners"
  instance_description = "VM running GitHub Actions Runners"
  region               = "europe-west4"
  machine_type         = "n2-standard-2"
  can_ip_forward       = false

  metadata = {
    google-logging-enabled = true
    enable-oslogin         = true
    startup-script = templatefile("${path.module}/startup.sh",
      {
        secret = google_secret_manager_secret.github_runner_org_token.secret_id
      }
    )
    shutdown-script = templatefile("${path.module}/shutdown.sh",
      {
        secret = google_secret_manager_secret.github_runner_org_token.secret_id
      }
    )
  }

  # Using the below scheduling configuration,
  # the MIG (managed instance group) will recreate the Spot VM if Compute Engine stops them
  scheduling {
    automatic_restart           = false
    preemptible                 = true
    provisioning_model          = "SPOT"
    on_host_maintenance         = "TERMINATE"
    instance_termination_action = "STOP"
  }

  # Ephemeral OS boot disk
  disk {
    source_image = data.google_compute_image.ubuntu.self_link
    auto_delete  = true
    boot         = true
    disk_type    = "pd-ssd"
  }

  network_interface {
    subnetwork         = google_compute_subnetwork.example.id
    subnetwork_project = var.project_id
  }

  shielded_instance_config {
    enable_integrity_monitoring = true
    enable_vtpm                 = true
    enable_secure_boot          = true
  }

  service_account {
    email  = google_service_account.gha_runners.email
    scopes = ["cloud-platform"]
  }

  project = var.project_id

  # Instance Templates cannot be updated after creation with the Google Cloud Platform API.
  # In order to update an Instance Template, Terraform will destroy the existing resource and create a replacement
  lifecycle {
    create_before_destroy = true
  }
}

# MIG that manages the lifecycle of the VMs
resource "google_compute_instance_group_manager" "gha_runners" {
  name               = "gha-runners"
  base_instance_name = "gha-runner"
  zone               = "europe-west4-a"
  description        = "Responsible for managing the VMs running GitHub Actions Runners"

  version {
    instance_template = google_compute_instance_template.gha_runners.id
  }

  target_size = 1

  update_policy {
    type                           = "PROACTIVE"
    minimal_action                 = "REPLACE"
    most_disruptive_allowed_action = "REPLACE"
    max_surge_fixed                = 0
    max_unavailable_fixed          = 1
    replacement_method             = "RECREATE"
  }

  project = var.project_id
}
