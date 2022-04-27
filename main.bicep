param rglocation string = 'australiaeast'
@minLength(1)
@maxLength(20)
param adminusername string = 'adflab'
@secure()
param adminpassword string
@secure()
param sqlpassword string = newGuid()

var vmname = 'adf-lab-vm'
var nicname = 'adf-lab-vm-nic1'
var adfname = 'adf-lab-${uniqueString(resourceGroup().id)}'
var kvname = 'adf-lab-kv-${uniqueString(resourceGroup().id)}'
var storagename = 'adfstorage${uniqueString(resourceGroup().id)}'
var sqlname = 'adfsql${uniqueString(resourceGroup().id)}'
var databasename = 'sampledata'
var sqlusername = 'adfsqladmin'

// This id is for "Key Vault Reader"
var kvreaderrole = '21090545-7ca7-4776-b22c-e363652d74d2'
// This id is for "Storage Blob Data Contributor"
var blobcontributorrole = 'ba92f5b4-2d11-453d-a403-e96b0029c9fe'

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
/*resource bastion 'Microsoft.Network/bastionHosts@2019-04-01' = {
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
}*/

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

resource storage 'Microsoft.Storage/storageAccounts@2021-08-01' = {
  name: storagename
  location: rglocation
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
    publicNetworkAccess: 'Enabled'
    allowBlobPublicAccess: true
    allowSharedKeyAccess: false
    allowCrossTenantReplication: false
    defaultToOAuthAuthentication: false
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Allow'
    }
    encryption: {
      keySource: 'Microsoft.Storage'
      services: {
        blob: {
          enabled: true
        }
        file: {
          enabled: true
        }
        table: {
          enabled: true
        }
        queue: {
          enabled: true
        }
      }
      requireInfrastructureEncryption: false
    }
  }
}

resource storageadfrole 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = {
  scope: storage
  name: guid(storage.id, adf.id, blobcontributorrole)
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', blobcontributorrole)
    principalId: adf.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

resource sqlserver 'Microsoft.Sql/servers@2021-11-01-preview' = {
  name: sqlname
  location: rglocation
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    version: '12.0'
    administratorLogin: sqlusername
    administratorLoginPassword: sqlpassword
  }
}

resource sqlfirewall 'Microsoft.Sql/servers/firewallRules@2021-11-01-preview' = {
  name: 'AllowAllWindowsAzureIps'
  parent: sqlserver
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '0.0.0.0'
  }
}

resource database 'Microsoft.Sql/servers/databases@2021-11-01-preview' = {
  name: 'databasename'
  parent: sqlserver
  location: rglocation
  sku: {
    name: 'S0'
    tier: 'Standard'
  }
  properties: {
    collation: 'SQL_Latin1_General_CP1_CI_AS'
    maxSizeBytes: 2147483648
  }
}

resource kvdbconnection 'Microsoft.KeyVault/vaults/secrets@2021-11-01-preview' = {
  name: 'adfsqladmin'
  parent: keyvault
  properties: {
    value: sqlpassword
  }
}

// Define linked services for Azure Data Factory
resource adflinkedkv 'Microsoft.DataFactory/factories/linkedservices@2018-06-01' = {
  name: 'AzureKeyVaultLinkedService'
  parent: adf
  properties: {
    type: 'AzureKeyVault'
    typeProperties: {
      baseUrl: keyvault.properties.vaultUri
    }
  }
}

resource adflinkedstorage 'Microsoft.DataFactory/factories/linkedservices@2018-06-01' = {
  name: 'AzureStorage'
  parent: adf
  properties: {
    type: 'AzureBlobStorage'
    typeProperties: {
      accountKind: 'StorageV2'
      serviceEndpoint: storage.properties.primaryEndpoints.blob
    }
  }
}

resource adflinkedsql 'Microsoft.DataFactory/factories/linkedservices@2018-06-01' = {
  name: 'AzureSql'
  parent: adf
  properties: {
    type: 'AzureSqlDatabase'
    typeProperties: {
      connectionString: database.properties.
      password: {
        type: 'AzureKeyVaultSecret'
        store: {
          referenceName: 'Data Source=tcp:${sqlserver.properties.fullyQualifiedDomainName},1433;Initial Catalog=${databasename};User ID=${sqlusername}@${sqlfirewall.name};Trusted Connection=False;Encrypt=True;Connection Timeout=30'
          type: 'LinkedServiceReference'
        }
        secretName: kvdbconnection.name
      }
    }
  }
}
