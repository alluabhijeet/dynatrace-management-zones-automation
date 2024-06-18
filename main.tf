locals {
  management_zones = flatten([
    for mz in yamldecode(file("${path.module}/management_zones.yaml"))["management_zones"] : [
      for env in mz.envs : {
        name = mz.name
        namespaces = mz.namespaces
        env = env
        provider = env == "PROD" ? "Prod" : "Non-Prod"
      }
    ]
  ])
}

# Define multiple providers for each environment
provider "dynatrace" {
  alias     = "Non-Prod"
  api_url   = "https://non-prod.dynatrace.com/api"
  api_token = "non-prod-token"
}

provider "dynatrace" {
  alias     = "Prod"
  api_url   = "https://prod.dynatrace.com/api"
  api_token = "prod-token"
}

resource "dynatrace_management_zone_v2" "mz" {
  for_each = { for mz in local.management_zones : "${mz.name}-${mz.env}" => mz }

  provider = dynatrace.${each.value.provider}

  name = "[${each.value.name}][${each.value.env}] ${each.value.name}"

  dynamic "rules" {
    for_each = each.value.namespaces

    content {
      rule {
        type            = "ME"
        enabled         = true
        entity_selector = "type(KUBERNETES_CLUSTER),entityName(_${rules.value})"
      }

      rule {
        type            = "ME"
        enabled         = true
        entity_selector = "type(HOST),toRelationships.isClusterOfHost(type(KUBERNETES_CLUSTER),namespace(${rules.value}))"
      }

      rule {
        type            = "ME"
        enabled         = true
        entity_selector = "type(CLOUD_APPLICATION),toRelationships.isClusterOfCa(type(KUBERNETES_CLUSTER),namespace(${rules.value}))"
      }

      rule {
        type            = "ME"
        enabled         = true
        entity_selector = "type(PROCESS_GROUP),fromRelationships.isPgOfCa(type(CLOUD_APPLICATION),namespace(${rules.value}))"
      }

      rule {
        type            = "ME"
        enabled         = true
        entity_selector = "type(PROCESS_GROUP_INSTANCE),fromRelationships.isInstanceOf(type(PROCESS_GROUP),namespace(${rules.value}))"
      }

      rule {
        type            = "ME"
        enabled         = true
        entity_selector = "type(CONTAINER_GROUP_INSTANCE),fromRelationships.isCgiOfCluster(type(KUBERNETES_CLUSTER),namespace(${rules.value}))"
      }

      rule {
        type            = "ME"
        enabled         = true
        entity_selector = "type(SERVICE),fromRelationships.runsOn(type(PROCESS_GROUP),namespace(${rules.value}))"
      }

      rule {
        type            = "ME"
        enabled         = true
        entity_selector = "type(APPLICATION),fromRelationships.calls(type(SERVICE),namespace(${rules.value}))"
      }

      rule {
        type            = "ME"
        enabled         = true
        entity_selector = "type(SYNTHETIC_TEST),fromRelationships.monitors(type(APPLICATION),namespace(${rules.value}))"
      }
    }
  }
}
