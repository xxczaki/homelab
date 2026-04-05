terraform {
  cloud {
    organization = "parsify"
    workspaces {
      name = "homelab-grafana"
    }
  }

  required_providers {
    grafana = {
      source  = "grafana/grafana"
      version = "~> 3.0"
    }
  }
}

provider "grafana" {
  url  = var.grafana_url
  auth = var.grafana_sa_token

  oncall_url          = "https://oncall-prod-eu-west-0.grafana.net/oncall"
  oncall_access_token = var.oncall_access_token
}
