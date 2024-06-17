locals {
  management_zones = flatten([
    for mz in yamldecode(file("${path.module}/management_zones.yaml"))["management_zones"] : [
      for env in mz.envs : {
        name = mz.name
        namespace = mz.namespace
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

  provider = dynatrace[each.value.provider]

  name = "[${each.value.name}][${each.value.env}] ${each.value.name}"

  rules {
    rule {
      type            = "SELECTOR"
      enabled         = true
      entity_selector = "type(KUBERNETES_CLUSTER),entityName(_${each.value.namespace})"
    }

    rule {
      type            = "SELECTOR"
      enabled         = true
      entity_selector = "type(HOST),toRelationships.isClusterOfHost(type(KUBERNETES_CLUSTER),namespace(${each.value.namespace}))"
    }

    rule {
      type            = "SELECTORE"
      enabled         = true
      entity_selector = "type(CLOUD_APPLICATION),toRelationships.isClusterOfCa(type(KUBERNETES_CLUSTER),namespace(${each.value.namespace}))"
    }

    rule {
      type            = "SELECTOR"
      enabled         = true
      entity_selector = "type(PROCESS_GROUP),fromRelationships.isPgOfCa(type(CLOUD_APPLICATION),namespace(${each.value.namespace}))"
    }

    rule {
      type            = "SELECTOR"
      enabled         = true
      entity_selector = "type(PROCESS_GROUP_INSTANCE),fromRelationships.isInstanceOf(type(PROCESS_GROUP),namespace(${each.value.namespace}))"
    }

    rule {
      type            = "SELECTOR"
      enabled         = true
      entity_selector = "type(CONTAINER_GROUP_INSTANCE),fromRelationships.isCgiOfCluster(type(KUBERNETES_CLUSTER),namespace(${each.value.namespace}))"
    }

    rule {
      type            = "SELECTOR"
      enabled         = true
      entity_selector = "type(SERVICE),fromRelationships.runsOn(type(PROCESS_GROUP),namespace(${each.value.namespace}))"
    }

    rule {
      type            = "SELECTOR"
      enabled         = true
      entity_selector = "type(APPLICATION),fromRelationships.calls(type(SERVICE),namespace(${each.value.namespace}))"
    }

    rule {
      type            = "SELECTOR"
      enabled         = true
      entity_selector = "type(SYNTHETIC_TEST),fromRelationships.monitors(type(APPLICATION),namespace(${each.value.namespace}))"
    }
  }
}
