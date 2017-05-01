#------------------------------------------------------------------------------
# Variables:
#------------------------------------------------------------------------------

:local dhcpEnabled 0
:local wlanEnabled 0

:local wlanGuestEnabled 1
:local wlanFrequency "auto"

:local localWlanInterface "wlan1"
:local localWlanSSID "XXX-LOCAL_WLAN_SSID-XXX"
:local localWlanKey "XXX-LOCAL_WLAN_KEY-XXX"

:local guestBridge "guests1"
:local guestWlanInterface "wlan2"
:local guestNetMask "24"
:local guestGateway "192.168.2.1"
:local guestNetwork "192.168.2.0"
:local guestDNSServer "8.8.8.8"
:local guestLeaseRange "192.168.2.100-192.168.2.254"
:local guestWlanSSID "XXX-GUEST_WLAN_SSID-XXX"
:local guestWlanKey "XXX-GUEST_WLAN_KEY-XXX"

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
# Switch:
#------------------------------------------------------------------------------

# Switch chip 1:
/interface ethernet {
  set [ find default-name=ether3 ] master-port=ether2
  set [ find default-name=ether4 ] master-port=ether2
  set [ find default-name=ether5 ] master-port=ether2
}

# Switch chip 2:
/interface ethernet {
  set [ find default-name=ether7 ] master-port=ether6
  set [ find default-name=ether8 ] master-port=ether6
  set [ find default-name=ether9 ] master-port=ether6
}

#------------------------------------------------------------------------------
# PPPoE Client:
#------------------------------------------------------------------------------

# Cleanup:
/interface vlan remove [find name="vlan6"]
/interface pppoe-client remove [find name="pppoe-out1"]

# Fibre to the home:
/interface vlan add interface=ether1 name=vlan6 vlan-id=6
/interface pppoe-client add add-default-route=yes allow=pap,chap disabled=no \
interface=vlan6 max-mru=1492 max-mtu=1492 name=pppoe-out1 password=adslppp \
service-name=FTTH use-peer-dns=yes user=adslppp@telefonicanetpa
/ip firewall nat add action=masquerade chain=srcnat out-interface=pppoe-out1

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
  dhcp-server network remove [find address="192.168.1.0/24"]
}

# Residents bridge, bridge-port and gateway IP:
/interface bridge add name=bridge1
/interface bridge port add bridge=bridge1 interface=wlan1
/ip address add address=192.168.1.1/24 interface=bridge1 network=192.168.1.0

# Residents DHCP:
:if ( $dhcpEnabled = 1 ) do={ /ip {
    pool add name=dhcp ranges="192.168.1.100-192.168.1.254"
    dhcp-server add address-pool=dhcp disabled=no interface="bridge1" name=dhcp1
    dhcp-server network add address=192.168.1.0/24 dns-server=8.8.8.8 gateway=192.168.1.1
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
    set $localWlanInterface band=5ghz-onlyn disabled=no \
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
