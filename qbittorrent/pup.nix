{ pkgs ? import <nixpkgs> {} }:

# qBittorrent (headless, WebUI) pup for Dogebox.
# Web UI on port 8080 (dogebox maps it to a host port). Downloads land in
# /storage/downloads and are bridged to Radarr/Sonarr by the host sync timer.
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
    Downloads\SavePath=/storage/downloads
    Downloads\Sequential=false
    EOF
    fi
    exec ${app}/bin/qbittorrent-nox --webui-port=8080
  '';
in
{
  qbittorrent = run;
}
