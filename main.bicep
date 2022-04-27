param rglocation string = 'australiaeast'
@minLength(1)
@maxLength(20)
param adminusername string = 'adflab'
@secure()
param adminpassword string

var vmname = 'adf-lab-vm'
var nicname = 'adf-lab-vm-nic1'
var adfname = 'adf-lab-${uniqueString(resourceGroup().id)}'
var kvname = 'adf-lab-kv-${uniqueString(resourceGroup().id)}'

// This id is for "Key Vault Reader"
var kvreaderrole = '21090545-7ca7-4776-b22c-e363652d74d2'

resource vnet 'Microsoft.Network/virtualNetworks@2021-05-01' = {
  name: 'adf-lab-vnet'
  location: rglocation
  properties: {
    addressSpace: {
      addressPrefixes: [
        '172.16.1.0/24'
      ]
    }
    subnets: [
      {
        name: 'GatewaySubnet'
        properties: {
          addressPrefix: '172.16.1.0/26'
        }
      }
      {
        name: 'AzureBastionSubnet'
        properties: {
          addressPrefix: '172.16.1.64/26'
        }
      }
      {
        name: 'vm'
        properties: {
          addressPrefix: '172.16.1.128/26'
        }
      }
    ]
    enableDdosProtection: false
  }
}

resource bastionpublicip 'Microsoft.Network/publicIPAddresses@2021-05-01' = {
  name: 'adf-lab-bastionip'
  location: rglocation
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
    idleTimeoutInMinutes: 4
  }
}

// Bastion did not work using the "Standard" SKU
resource bastion 'Microsoft.Network/bastionHosts@2019-04-01' = {
  name: 'adf-lab-bastion'
  location: rglocation
  properties: {
    ipConfigurations: [
      {
        name: 'IpConf'
        properties: {
          subnet: {
            id: '${vnet.id}/subnets/AzureBastionSubnet'
          }
          publicIPAddress: {
            id: bastionpublicip.id
          }
        }
      }
    ]
  }
}

resource irvmnsg 'Microsoft.Network/networkSecurityGroups@2021-05-01' = {
  name: 'adf-lab-vm-nsg'
  location: rglocation
}

resource irvmnic 'Microsoft.Network/networkInterfaces@2021-05-01' = {
  name: nicname
  location: rglocation
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAddressVersion: 'IPv4'
          subnet: {
            id: '${vnet.id}/subnets/vm'
          }
          privateIPAllocationMethod: 'Dynamic'
        }
      }
    ]
    networkSecurityGroup: {
      id: irvmnsg.id
    }
  }
}

resource irvm 'Microsoft.Compute/virtualMachines@2021-11-01' = {
  name: vmname
  location: rglocation
  properties: {
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: false
      }
    }
    hardwareProfile: {
      vmSize: 'Standard_B2s'
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: irvmnic.id
          properties: {
            deleteOption: 'Delete'
          }
        }
      ]
    }
    osProfile: {
      computerName: vmname
      adminUsername: adminusername
      adminPassword: adminpassword
      windowsConfiguration: {
        enableAutomaticUpdates: true
        provisionVMAgent: true
        patchSettings: {
          enableHotpatching: false
          patchMode: 'AutomaticByOS'
        }
      }
    }
    storageProfile: {
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'Premium_LRS'
        }
        deleteOption: 'Delete'
      }
      imageReference: {
        publisher: 'MicrosoftWindowsServer'
        offer: 'WindowsServer'
        sku: '2019-datacenter-gensecond'
        version: 'latest'
      }
    }
  }
}

resource adf 'Microsoft.DataFactory/factories@2018-06-01' = {
  name: adfname
  location: rglocation
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
  }
}

resource keyvault 'Microsoft.KeyVault/vaults@2021-10-01' = {
  name: kvname
  location: rglocation
  properties: {
    enableRbacAuthorization: true
    sku: {
      family: 'A'
      name: 'standard'
    }
    softDeleteRetentionInDays: 7
    tenantId: tenant().tenantId
  }
}

resource kvadfrole 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = {
  scope: keyvault
  name: guid(keyvault.id, adf.id, kvreaderrole)
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', kvreaderrole)
    principalId: adf.identity.principalId
    principalType: 'ServicePrincipal'
  }
}
