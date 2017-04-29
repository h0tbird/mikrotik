#------------------------------------------------------------------------------
# Variables:
#------------------------------------------------------------------------------

:local wlanEnabled 0
:local wlanFrequency "auto"

:local localWlanInterface "wlan1"
:local localWlanSSID "XXX-LOCAL_WLAN_SSID-XXX"
:local localWlanKey "XXX-LOCAL_WLAN_KEY-XXX"

:local guestBridge "guest1"
:local guestWlanInterface "wlan2"
:local guestWlanSSID "XXX-GUEST_WLAN_SSID-XXX"
:local guestWlanKey "XXX-GUEST_WLAN_KEY-XXX"

#------------------------------------------------------------------------------
# Packages:
#------------------------------------------------------------------------------

# Wireless is automatically set if package is installed:
:if ([:len [/system package find name="wireless" !disabled]] != 0) do={
  :set wlanEnabled 1
}

#------------------------------------------------------------------------------
# Wireless:
#------------------------------------------------------------------------------

# Set up the wireless interfaces:
:if ( $wlanEnabled = 1 ) do={

  # Cleanup:
  /interface wireless {
    reset-configuration [/interface wireless find]
    security-profiles remove [find name!=default]
    remove [find name=$guestWlanInterface]
  }

  # Resident network:
  /interface wireless {
    security-profiles add name="local" mode=dynamic-keys \
    authentication-types=wpa2-psk wpa2-pre-shared-key=$localWlanKey
    set $localWlanInterface band=5ghz-onlyn disabled=no \
    frequency=$wlanFrequency mode=ap-bridge security-profile=local \
    ssid=$localWlanSSID country=spain hide-ssid=no wireless-protocol=802.11
  }

  # Guest bridge:
  /interface bridge {
    remove [find name=$guestBridge]
    add name=$guestBridge
  }

  # Guest network:
  /interface wireless {
    security-profiles add name="guest" mode=dynamic-keys \
    authentication-types=wpa2-psk wpa2-pre-shared-key=$guestWlanKey
    add disabled=no master-interface=$localWlanInterface \
    mode=ap-bridge name=$guestWlanInterface ssid=$guestWlanSSID \
    wds-default-bridge=$guestBridge wps-mode=disabled
  }

  # Bridge port:
  /interface bridge port add bridge=$guestBridge interface=$guestWlanInterface
}
