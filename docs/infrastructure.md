# Server infrastructure

Ensure that high bandwidth traffic is not routed through `Telescoop`
to prevent unnecessary load on the cloud server!

Instead, route traffic directly to the `Melkweg` cluster.
Use `Telescoop` only for public-facing services.

- `Raket` = VLAN
- `Heelal` = Entire infrastructure
- `Kuipergordel` = Outermost firewall
- `Melkweg` = Proxmox cluster / Placement group
  - `Aarde` = Proxmox node
    - Caddy
      - Reverse proxy Proxmox web interface `https://aarde.melkweg.jrzutphen.dev`
    - `pve-docker` = LXC container
      - `Kompas` = Caddy `https://kompas.jrzutphen.dev`
        - Reverse proxy Proxmox web interface `https://kompas.jrzutphen.dev/melkweg`
      - Portainer `https://kompas.jrzutphen.dev/haven`
- `Telescoop` = Cloud server `https://telescoop.jrzutphen.dev`
  - Caddy
    - Serve `https://error.jrzutphen.nl` and `https://error.jrzutphen.eu`
    - Proxy all traffic on `jrzutphen.nl` to `https://kompas.jrzutphen.dev`
      - 302 redirect to `https://error.jrzutphen.nl` if `Kompas` is down
    - Proxy all traffic on `jrzutphen.eu` to `https://kompas.jrzutphen.dev`
      - 302 redirect to `https://error.jrzutphen.eu` if `Kompas` is down

## DNS set-up

Available IPs:

- 136.243.130.114 = main `Aarde` IPv4 address = `aarde.melkweg.jrzutphen.dev`
- 136.243.130.109 = secondary `Aarde` IPv4 address = `kompas.jrzutphen.dev`
- 2a01:4f8:212:3203::/64 = `Aarde` IPv6 subnet
- 167.235.71.13 = main `Telescoop` IPv4 address = `telescoop.jrzutphen.dev`
- 2a01:4f8:1c1c:1e9e::/64 = `Telescoop` IPv6 subnet

Subnet: `Raket`

- Dedicated: 192.168.1.0/24
- Cloud: 192.168.2.0/24
