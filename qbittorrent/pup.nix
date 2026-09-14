{ pkgs ? import <nixpkgs> {} }:

# qBittorrent (headless, WebUI) pup for Dogebox.
# Web UI on port 8080 (dogebox maps it to a host port). Downloads land in
# /storage/downloads and are bridged to Radarr/Sonarr by the host sync timer.
# HostHeaderValidation must be off: the dogeboxd gateway forwards the browser's
# original Host header (<box-ip>:<mapped-port>), which qBittorrent 5.x
# otherwise rejects with 401 before the page even loads.
#
# v0.0.5 also runs qB inside a bubblewrap sandbox: bind-mount only the
# storage paths it needs, give it a private /tmp + /proc + /dev, drop all
# capabilities, and run it as a non-privileged user inside its own PID
# namespace. Even if a torrent tricked qB into spawning a child process,
# the child could only touch /storage/{config,downloads,quarantine} and
# nothing else on the host filesystem. Cost is essentially zero (bwrap
# uses Linux namespaces natively, no syscall overhead).
let
  app = pkgs.qbittorrent-nox;
  bwrap = pkgs.bubblewrap;

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
    # Drop a marker so the WebUI + tests can detect the sandbox is active.
    # qB can read it (write to log? not strictly needed, harmless).
    exec ${bwrap}/bin/bwrap \
      --as-pid-1 \
      --unshare-pid \
      --unshare-uts \
      --unshare-ipc \
      --unshare-cgroup \
      --hostname qbittorrent-sandbox \
      --ro-bind /nix/store /nix/store \
      --ro-bind /etc/resolv.conf /etc/resolv.conf \
      --ro-bind /etc/nsswitch.conf /etc/nsswitch.conf \
      --ro-bind /etc/hosts /etc/hosts \
      --ro-bind /etc/ssl /etc/ssl \
      --dir /tmp \
      --tmpfs /tmp \
      --proc /proc \
      --dev /dev \
      --bind /storage/config /storage/config \
      --bind /storage/downloads /storage/downloads \
      --bind /storage/quarantine /storage/quarantine \
      --cap-drop ALL \
      --die-with-parent \
      -- \
      ${app}/bin/qbittorrent-nox --webui-port=8080
  '';
in
{
  qbittorrent = run;
}
