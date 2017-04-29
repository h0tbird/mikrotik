#------------------------------------------------------------------------------
# Variables:
#------------------------------------------------------------------------------

:local wlanEnabled 0;
:local wlanInterface "wlan1";

:local localWlanFrequency "auto";
:local localWlanSSID "XXX-LOCAL_WLAN_SSID-XXX";
:local localWlanKey "XXX-LOCAL_WLAN_KEY-XXX";

:local guestWlanFrequency "auto";
:local guestWlanSSID "XXX-GUEST_WLAN_SSID-XXX";
:local guestWlanKey "XXX-GUEST_WLAN_KEY-XXX";

#------------------------------------------------------------------------------
# Wireless:
#------------------------------------------------------------------------------

# Wireless is automatically set if package is installed:
:if ([:len [/system package find name="wireless" !disabled]] != 0) do={
  :set wlanEnabled 1;
}

# Set up the wireless interface:
:if ( $wlanEnabled = 1 ) do={
  /interface wireless reset-configuration [/interface wireless find];
  /interface wireless security-profiles remove [find name!=default];
  /interface wireless security-profiles add name="home" mode=dynamic-keys \
    authentication-types=wpa2-psk wpa2-pre-shared-key="$localWlanKey";
  /interface wireless set $wlanInterface band=5ghz-onlyn disabled=no \
    frequency=$localWlanFrequency mode=ap-bridge security-profile=home \
    ssid=$localWlanSSID country=spain hide-ssid=no wireless-protocol=802.11;
}
