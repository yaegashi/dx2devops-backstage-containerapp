param dnsZoneName string
param dnsRecordName string
param txt string

resource dnsZone 'Microsoft.Network/dnsZones@2018-05-01' existing = {
  name: dnsZoneName
}

resource dnsRecord 'Microsoft.Network/dnsZones/TXT@2018-05-01' = {
  parent: dnsZone
  name: dnsRecordName
  properties: {
    TTL: 3600
    TXTRecords: [
      {
        value: [
          txt
        ]
      }
    ]
  }
}
