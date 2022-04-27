param rglocation string = 'australiaeast'
@minLength(1)
@maxLength(20)
param adminusername string = 'adflab'
@secure()
@minLength(12)
@maxLength(128)
param adminpassword string

var vmname = 'adf-lab-vm'
var nicname = 'adf-lab-vm-nic1'
var adfname = 'adf-lab-${uniqueString(subscription().subscriptionId)}'

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
  }
}

resource bastionpublicip 'Microsoft.Network/publicIPAddresses@2021-05-01' = {
  name: 'adf-lab-bastionip'
  location: rglocation
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

resource bastion 'Microsoft.Network/bastionHosts@2021-05-01' = {
  name: 'adf-lab-bastion'
  location: rglocation
  sku: {
    name: 'Standard'
  }
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig'
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

resource irvmnic 'Microsoft.Network/networkInterfaces@2021-05-01' = {
  name: nicname
  location: rglocation
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: '${vnet.id}/subnets/vm'
          }
          privateIPAllocationMethod: 'Dynamic'
        }
      }
    ]
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
