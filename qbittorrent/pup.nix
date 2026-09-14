{ pkgs ? import <nixpkgs> {} }:

# qBittorrent (headless, WebUI) pup for Dogebox.
# Web UI on port 8080 (dogebox maps it to a host port). Downloads land in
# /storage/downloads and are bridged to Radarr/Sonarr by the host sync timer.
# HostHeaderValidation must be off: the dogeboxd gateway forwards the browser's
# original Host header (<box-ip>:<mapped-port>), which qBittorrent 5.x
# otherwise rejects with 401 before the page even loads.
let
  app = pkgs.qbittorrent-nox;

  run = pkgs.writeScriptBin "run.sh" ''
    #!${pkgs.stdenv.shell}
    export HOME=/storage/config
    export XDG_CONFIG_HOME=/storage/config/xdg
    mkdir -p /storage/config/xdg/qBittorrent /storage/downloads
    CONF=/storage/config/xdg/qBittorrent/qBittorrent.conf
    if [ ! -f "$CONF" ]; then
      cat > "$CONF" <<'EOF'
    [Preferences]
    WebUI\Enabled=true
    WebUI\Port=8080
    WebUI\LocalHostAuth=false
    WebUI\AuthSubnetWhitelistEnabled=true
    WebUI\AuthSubnetWhitelist=10.69.0.0/16, 127.0.0.1/32
    WebUI\HostHeaderValidation=false
    Downloads\SavePath=/storage/downloads
    Downloads\Sequential=false
    EOF
    fi
    # The conf above is write-if-missing, so pre-0.0.2 installs never receive
    # new defaults. If the key is absent, insert it under [Preferences]
    # (section-anchored: a plain append could land after a later section
    # once qBittorrent rewrites the file). Store paths are used because the
    # container service PATH only carries coreutils/util-linux.
    ${pkgs.gnugrep}/bin/grep -q '^WebUI\\HostHeaderValidation=' "$CONF" || \
      ${pkgs.gnused}/bin/sed -i '/^\[Preferences\]/a WebUI\\HostHeaderValidation=false' "$CONF"
    # dogeboxd always forwards the browser's Host header, so validation can
    # never pass through the gateway — if it got re-enabled in the WebUI
    # settings, normalize it back off or every dashboard launch 401s again.
    ${pkgs.gnused}/bin/sed -i 's/^WebUI\\HostHeaderValidation=true$/WebUI\\HostHeaderValidation=false/' "$CONF"
    exec ${app}/bin/qbittorrent-nox --webui-port=8080
  '';
in
{
  qbittorrent = run;
}
