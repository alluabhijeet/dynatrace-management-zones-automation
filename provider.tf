terraform {
  required_providers {
    dynatrace = {
      version = "1.54.0"
      source  = "dynatrace-oss/dynatrace"
    }
  }
}

# Define multiple providers for each environment
provider "dynatrace" {
  alias     = "Non-Prod"
  dt_env_url   = "https://non-prod.dynatrace.com/api"
  dt_api_token = "non-prod-token"
}

provider "dynatrace" {
  alias     = "Prod"
  dt_env_url   = "https://prod.dynatrace.com/api"
  dt_api_token = "prod-token"