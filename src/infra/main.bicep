// Azure Kubernetes Service and Container Registry deployment
// This template creates an AKS cluster with ACR integration using Managed Identity

@description('The name of the AKS cluster')
param clusterName string

@description('The name of the Azure Container Registry')
param acrName string

@description('The location for all resources')
param location string = resourceGroup().location

@description('The DNS prefix for the AKS cluster')
param dnsPrefix string = clusterName

@description('The VM size for the AKS nodes')
param nodeVmSize string = 'Standard_DS2_v2'

@description('The initial number of nodes in the AKS cluster')
@minValue(1)
@maxValue(10)
param nodeCount int = 2

@description('The Kubernetes version')
param kubernetesVersion string = '1.34'

// Container Registry
resource acr 'Microsoft.ContainerRegistry/registries@2023-11-01-preview' = {
  name: acrName
  location: location
  sku: {
    name: 'Premium'
  }
  properties: {
    adminUserEnabled: false
    anonymousPullEnabled: false
    policies: {
      retentionPolicy: {
        status: 'enabled'
        days: 7
      }
    }
  }
}

// AKS Cluster
resource aksCluster 'Microsoft.ContainerService/managedClusters@2024-01-01' = {
  name: clusterName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    dnsPrefix: dnsPrefix
    kubernetesVersion: kubernetesVersion
    enableRBAC: true
    agentPoolProfiles: [
      {
        name: 'nodepool1'
        count: nodeCount
        vmSize: nodeVmSize
        osType: 'Linux'
        osDiskSizeGB: 256
        mode: 'System'
        minCount: 1
        maxCount: 5
        enableAutoScaling: true
        type: 'VirtualMachineScaleSets'
      }
    ]
    networkProfile: {
      networkPlugin: 'azure'
      loadBalancerSku: 'standard'
      serviceCidr: '10.0.0.0/16'
      dnsServiceIP: '10.0.0.10'
    }
    aadProfile: {
      managed: true
      enableAzureRBAC: true
    }
  }
}

// Role assignment for AKS to pull images from ACR
// Uses AcrPull role (7f951dda-4ed3-4680-a7ca-43fe172d538d)
resource acrPullRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, aksCluster.id, 'acrpull')
  scope: acr
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '7f951dda-4ed3-4680-a7ca-43fe172d538d')
    principalId: aksCluster.properties.identityProfile.kubeletidentity.objectId
    principalType: 'ServicePrincipal'
  }
}

// Outputs
output aksClusterName string = aksCluster.name
output aksClusterFqdn string = aksCluster.properties.fqdn
output acrLoginServer string = acr.properties.loginServer
output acrName string = acr.name
output aksKubeletIdentityObjectId string = aksCluster.properties.identityProfile.kubeletidentity.objectId
