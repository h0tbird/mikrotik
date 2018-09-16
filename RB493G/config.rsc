#------------------------------------------------------------------------------
# Delay because meh:
#------------------------------------------------------------------------------

:delay 15s

#------------------------------------------------------------------------------
# Variables:
#------------------------------------------------------------------------------

:global dhcpEnabled 0
:global wlanEnabled 0

:global wlanGuestEnabled 1
:global wlanFrequency "auto"
:global wlanBand "2ghz-b/g"

:global localWlanInterface "wlan1"
:global localWlanSSID "XXX-LOCAL_WLAN_SSID-XXX"
:global localWlanKey "XXX-LOCAL_WLAN_KEY-XXX"
:global localNetwork "192.168.1.0"
:global localNetMask "24"

:global guestBridge "guests1"
:global guestWlanInterface "wlan2"
:global guestNetMask "24"
:global guestGateway "192.168.2.1"
:global guestNetwork "192.168.2.0"
:global guestDNSServer "8.8.8.8"
:global guestLeaseRange "192.168.2.100-192.168.2.254"
:global guestWlanSSID "XXX-GUEST_WLAN_SSID-XXX"
:global guestWlanKey "XXX-GUEST_WLAN_KEY-XXX"

:global plexIP1 "192.168.1.199"
:global plexIP2 "192.168.1.200"
:global plexPort "32400"

#------------------------------------------------------------------------------
# Packages:
#------------------------------------------------------------------------------

:if ([:len [/system package find name="wireless" !disabled]] != 0) do={
  :set wlanEnabled 1
}

:if ([:len [/system package find name="dhcp" !disabled]] != 0) do={
  :set dhcpEnabled 1
}

#------------------------------------------------------------------------------
# RouterOS services:
#------------------------------------------------------------------------------

# Disabled:
/ip service {
  set telnet disabled=yes
  set api disabled=yes
  set winbox disabled=yes
  set api-ssl disabled=yes
}

# Enabled:
/ip service {
  set ftp disabled=no
  set www disabled=no
  set ssh disabled=no
}

#------------------------------------------------------------------------------
# Global firewall:
#------------------------------------------------------------------------------

/ip firewall filter {
  add chain=input connection-state=established action=accept
  add chain=input connection-state=related action=accept
  add chain=input connection-state=invalid action=drop
}

#------------------------------------------------------------------------------
# PPPoE Client:
#------------------------------------------------------------------------------

# Cleanup:
/interface vlan remove [find name="vlan6"]
/interface pppoe-client remove [find name="pppoe-out1"]

# VLAN and PPPoE:
/interface {
  vlan add interface=ether1 name=vlan6 vlan-id=6
  pppoe-client add add-default-route=yes allow=pap,chap disabled=no \
  interface=vlan6 max-mru=1492 max-mtu=1492 name=pppoe-out1 password=adslppp \
  service-name=FTTH use-peer-dns=yes user=adslppp@telefonicanetpa
}

# NAT and firewall:
/ip firewall {
  nat add action=masquerade chain=srcnat out-interface=pppoe-out1
  filter add action=drop chain=input in-interface=pppoe-out1
}

#------------------------------------------------------------------------------
# Residents LAN:
#------------------------------------------------------------------------------

# Cleanup bridge:
/interface bridge {
  port remove [find bridge="bridge1"]
  remove [find name="bridge1"]
}

# Cleanup IP:
/ip {
  address remove [find interface="bridge1"]
  pool remove [find name="dhcp"]
  dhcp-server remove [find name="dhcp1"]
  dhcp-server network remove [find address="$localNetwork/$localNetMask"]
}

# Bridge and bridge-ports:
/interface bridge {
  add name=bridge1
  port add bridge=bridge1 interface=wlan1
  port add bridge=bridge1 hw=yes interface=ether2
  port add bridge=bridge1 hw=yes interface=ether3
  port add bridge=bridge1 hw=yes interface=ether4
  port add bridge=bridge1 hw=yes interface=ether5
  port add bridge=bridge1 hw=yes interface=ether6
  port add bridge=bridge1 hw=yes interface=ether7
  port add bridge=bridge1 hw=yes interface=ether8
  port add bridge=bridge1 hw=yes interface=ether9
}

# Gateway IP:
/ip address add address=192.168.1.1/24 interface=bridge1 network="$localNetwork"

# DHCP server:
:if ( $dhcpEnabled = 1 ) do={ /ip {
    pool add name=dhcp ranges="192.168.1.100-192.168.1.254"
    dhcp-server add address-pool=dhcp disabled=no interface="bridge1" name=dhcp1
    dhcp-server network add address="$localNetwork/$localNetMask" dns-server=8.8.8.8 gateway=192.168.1.1
  }
}

#------------------------------------------------------------------------------
# Residents wireless:
#------------------------------------------------------------------------------

:if ( $wlanEnabled = 1 ) do={

  # Cleanup wireless:
  /interface wireless {
    reset-configuration [/interface wireless find]
    security-profiles remove [find name!=default]
    remove [find name="$guestWlanInterface"]
  }

  # Cleanup bridge:
  /interface bridge {
    port remove [find bridge="$guestBridge"]
    remove [find name="$guestBridge"]
  }

  # Cleanup IP:
  /ip {
    address remove [find address="$guestGateway/$guestNetMask"]
    pool remove [find name="guest-pool"]
    dhcp-server remove [find name="guest-dhcp"]
    dhcp-server network remove [find address="$guestNetwork/$guestNetMask"]
    firewall nat remove [find src-address="$guestGateway/$guestNetMask"]
    firewall filter remove [find in-interface="$guestBridge"]
  }

  # Residents WiFi network:
  /interface wireless {
    security-profiles set [ find default=yes ] authentication-types=wpa2-psk \
    mode=dynamic-keys wpa2-pre-shared-key="$localWlanKey"
    set $localWlanInterface band="$wlanBand" disabled=no \
    frequency="$wlanFrequency" mode=ap-bridge security-profile=default \
    ssid="$localWlanSSID" country=spain hide-ssid=no wireless-protocol=802.11
  }

#------------------------------------------------------------------------------
# Guests wireless:
#------------------------------------------------------------------------------

  :if ( $wlanGuestEnabled = 1 ) do={

    # Guests bridge:
    /interface bridge add name="$guestBridge"

    # Guests WiFi network:
    /interface wireless {
      security-profiles add name=guest mode=dynamic-keys \
      authentication-types=wpa2-psk wpa2-pre-shared-key="$guestWlanKey"
      add disabled=no master-interface="$localWlanInterface" \
      mode=ap-bridge name="$guestWlanInterface" security-profile=guest \
      ssid="$guestWlanSSID" wds-default-bridge="$guestBridge" wps-mode=disabled
    }

    # Guests bridge-port, gateway IP and firewall:
    /interface bridge port add bridge="$guestBridge" interface="$guestWlanInterface"
    /ip address add address="$guestGateway/$guestNetMask" interface="$guestBridge" network="$guestNetwork"
    /ip firewall filter add action=drop chain=forward in-interface="$guestBridge" out-interface=!pppoe-out1

    # Guests DHCP:
    :if ( $dhcpEnabled = 1 ) do={ /ip {
        pool add name=guest-pool ranges="$guestLeaseRange"
        dhcp-server add address-pool=guest-pool disabled=no interface="$guestBridge" name=guest-dhcp
        dhcp-server network add address="$guestNetwork/$guestNetMask" \
        dns-server="$guestDNSServer" gateway="$guestGateway" netmask="$guestNetMask"
      }
    }
  }
}

#------------------------------------------------------------------------------
# PLEX media server:
#------------------------------------------------------------------------------

/ip firewall nat {
  add action=dst-nat chain=dstnat dst-port="$plexPort" protocol=tcp to-addresses="$plexIP1" to-ports="$plexPort"
  add action=masquerade chain=srcnat dst-address="$plexIP1" dst-port="$plexPort" out-interface=bridge1 protocol=tcp src-address="$localNetwork/$localNetMask"
  add action=masquerade chain=srcnat dst-address="$plexIP2" dst-port="$plexPort" out-interface=bridge1 protocol=tcp src-address="$localNetwork/$localNetMask"
}
