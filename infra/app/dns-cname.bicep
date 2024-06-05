param dnsZoneName string
param dnsRecordName string
param cname string

resource dnsZone 'Microsoft.Network/dnsZones@2018-05-01' existing = {
  name: dnsZoneName
}

resource dnsRecord 'Microsoft.Network/dnsZones/CNAME@2018-05-01' = {
  parent: dnsZone
  name: dnsRecordName
  properties: {
    TTL: 3600
    CNAMERecord: {
      cname: cname
    }
  }
}
