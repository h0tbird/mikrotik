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

:local guestBridge "guest1"
:local guestWlanInterface "wlan2"
:local guestNetwork "10.1.0.0"
:local guestIPAddress "10.1.0.0/24"
:local guestLeaseRange "10.1.0.100-10.1.0.254"
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
# Wireless:
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
    address remove [find address="$guestIPAddress"]
    pool remove [find name="guest-pool"]
    dhcp-server remove [find name="guest-dhcp"]
  }

  # Residents WiFi network:
  /interface wireless {
    security-profiles add name="local" mode=dynamic-keys \
    authentication-types=wpa2-psk wpa2-pre-shared-key=$localWlanKey
    set $localWlanInterface band=5ghz-onlyn disabled=no \
    frequency=$wlanFrequency mode=ap-bridge security-profile=local \
    ssid=$localWlanSSID country=spain hide-ssid=no wireless-protocol=802.11
  }

  :if ( $wlanGuestEnabled = 1 ) do={

    # Guests bridge:
    /interface bridge add name=$guestBridge

    # Guests WiFi network:
    /interface wireless {
      security-profiles add name="guest" mode=dynamic-keys \
      authentication-types=wpa2-psk wpa2-pre-shared-key=$guestWlanKey
      add disabled=no master-interface=$localWlanInterface \
      mode=ap-bridge name=$guestWlanInterface ssid=$guestWlanSSID \
      wds-default-bridge=$guestBridge wps-mode=disabled
    }

    # Bridge port:
    /interface bridge port add bridge=$guestBridge interface=$guestWlanInterface

    :if ( $dhcpEnabled = 1 ) do={

      /ip {
        address add address=$guestIPAddress interface=$guestBridge network=$guestNetwork
        pool add name=guest-pool ranges=$guestLeaseRange
        dhcp-server add address-pool=guest-pool disabled=no interface=$guestBridge name=guest-dhcp
      }
    }
  }
}
