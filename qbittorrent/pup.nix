{ pkgs ? import <nixpkgs> {} }:

# qBittorrent (headless, WebUI) pup for Dogebox.
# Web UI on port 8080 (dogebox maps it to a host port). Downloads land in
# /storage/downloads and are bridged to Radarr/Sonarr by the host sync timer.
# HostHeaderValidation must be off: the dogeboxd gateway forwards the browser's
# original Host header (<box-ip>:<mapped-port>), which qBittorrent 5.x
# otherwise rejects with 401 before the page even loads.
#
# v0.0.5 tried to run qB inside a bubblewrap sandbox (bind-mounted storage
# paths, private /tmp+/proc+/dev, all caps dropped). It never worked on a
# real Dogebox: systemd-nspawn pup containers may not mount a fresh /proc,
# so bwrap aborts with "Can't mount proc on /newroot/proc: Operation not
# permitted" and the service restart-loops (verified 2026-09-17 on-box,
# restart counter 5). The nixpkgs bubblewrap package is not setuid, and
# userns-clone alone is not enough for --proc inside nspawn.
# v0.0.6 reverts to a direct exec while KEEPING the 0.0.5 fixes that do
# work: HostHeaderValidation default-off + normalization, quarantine dir,
# write-if-missing conf template. The sandbox idea can return when the
# Dogebox nspawn profile grants mount-namespace capabilities.
let
  app = pkgs.qbittorrent-nox;

  run = pkgs.writeScriptBin "run.sh" ''
    #!${pkgs.stdenv.shell}
    export HOME=/storage/config
    export XDG_CONFIG_HOME=/storage/config/xdg
    mkdir -p /storage/config/xdg/qBittorrent /storage/downloads /storage/quarantine
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
    # Direct exec — see header note for why the 0.0.5 bwrap sandbox is gone.
    exec ${app}/bin/qbittorrent-nox --webui-port=8080
  '';
in
{
  qbittorrent = run;
}
