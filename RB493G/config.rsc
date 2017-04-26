#------------------------------------------------------------------------------
# Variables:
#------------------------------------------------------------------------------

:local wirelessEnabled 0;
:local wlanFrequency "auto";
:local wlanSSID "MYSSID";
:local wlanKey "xxxxxxxx";
:local wlanInterface "wlan1";

#------------------------------------------------------------------------------
# Wireless:
#------------------------------------------------------------------------------

# Wireless is automatically set if package is installed:
:if ([:len [/system package find name="wireless" !disabled]] != 0) do={
  :log info "Wireless package found, enabling wireless on router.";
    :set wirelessEnabled 1;
}

# Set up the wireless interface:
:if ( $wirelessEnabled = 1 ) do={
  :log info "Setting wireless LAN interface and security.";
  /interface wireless reset-configuration [/interface wireless find];
  /interface wireless security-profiles remove [find name!=default];
  /interface wireless security-profiles add name="home" mode=dynamic-keys \
    authentication-types=wpa2-psk wpa2-pre-shared-key="$wlanKey";
  /interface wireless set $wlanInterface band=5ghz-onlyn disabled=no \
    frequency=$wlanFrequency mode=ap-bridge security-profile=home \
    ssid=$wlanSSID country=spain hide-ssid=no wireless-protocol=802.11;
}
