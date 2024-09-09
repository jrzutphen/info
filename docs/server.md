# Set-up of the `Aarde` server

1. Install Debian:

   1. Log into Rescue system
   2. Run `installimage`
   3. Select Debian Bookworm
   4. Use the following configuration:

      ```conf
      DRIVE1 /dev/nvme0n1
      DRIVE2 /dev/nvme1n1

      SWRAID 1
      SWRAIDLEVEL 1

      HOSTNAME aarde.jrzutphen.dev

      USE_KERNEL_MODE_SETTING yes

      PART              /boot     ext4   1G
      PART              /boot/efi esp    1G
      PART              lvm       pve  448G

      LV pve    swap    swap      swap  32G
      LV pve    root    /         xfs  128G

      IMAGE /root/.oldroot/nfs/images/Debian-1205-bookworm-amd64-base.tar.gz
      ```

   5. Press `F2`, press confirm, press `F10`, and press confirm until the installation starts
   6. Reboot: `reboot`

2. Configure the system:

   1. Log in as `root`
   2. Configure the system details:

      ```bash
      hostnamectl hostname --pretty Aarde
      hostnamectl chassis server
      hostnamectl deployment production
      hostnamectl location "Datacenter 12, Falkenstein, Germany"
      sed -i 's/# en_GB.UTF-8 UTF-8/en_GB.UTF-8 UTF-8/' /etc/locale.gen
      sed -i 's/# nl_NL.UTF-8 UTF-8/nl_NL.UTF-8 UTF-8/' /etc/locale.gen
      locale-gen
      localectl set-locale LANG=en_GB.UTF-8

      ```

   3. Create the `data` logical volume:

      ```bash
      lvcreate --type thin-pool --size 256G --name data pve
      ```

   4. Install Proxmox VE

      ```bash
      curl --output /etc/apt/trusted.gpg.d/proxmox-release-bookworm.gpg http://download.proxmox.com/debian/proxmox-release-bookworm.gpg
      curl https://raw.githubusercontent.com/foundObjects/pve-nag-buster/master/install.sh | bash
      echo "deb http://download.proxmox.com/debian/pve bookworm pve-no-subscription" > /etc/apt/sources.list.d/pve-install-repo.list
      echo '# deb https://enterprise.proxmox.com/debian/pve bookworm InRelease' > /etc/apt/sources.list.d/pve-enterprise.list
      apt update
      apt full-upgrade
      apt install proxmox-default-kernel
      systemctl reboot
      # Wait for the system to come back online and log back in
      uname -r # Should include `pve`
      apt install proxmox-ve postfix open-iscsi chrony # Use all default values
      apt install libpve-network-perl
      apt remove linux-image-amd64 'linux-image-6.1*'
      apt remove os-prober
      update-grub
      systemctl reboot
      ```

   5. Edit `/etc/network/interfaces`:

      ```conf
      # PVE ignores sourced files!
      source /etc/network/interfaces.d/*

      # Loopback
      auto lo
      iface lo inet loopback
      iface lo inet6 loopback

      # Physical interface
      auto enp6s0
      iface enp6s0 inet static
              address 136.243.130.114/26
              gateway 136.243.130.65
              post-up echo 1 > /proc/sys/net/ipv4/ip_forward
      iface enp6s0 inet6 static
              address 2a01:4f8:212:3203::1/64
              gateway fe80::1
              post-up echo 1 > /proc/sys/net/ipv6/conf/all/forwarding

      # VLAN
      auto enp6s0.4000
      iface enp6s0.4000 inet static
              address 192.168.1.1/24
              vlan-raw-device enp6s0
              mtu 1400
              up   ip route del 192.168.0.0/16 via 192.168.1.1 dev enp6s0.4000
              down ip route del 192.168.0.0/16 via 192.168.1.1 dev enp6s0.4000

      # Bridge for external traffic
      auto vmbr0
      iface vmbr0 inet static
              address 136.243.130.114/32
              bridge_ports none
              bridge_stp off
              bridge_fd 0
              up   ip route add 136.243.130.109/32 dev vmbr0
              down ip route del 136.243.130.109/32 dev vmbr0
      iface vmbr1 inet6 static
              address 2a01:4f8:212:3203::2/64

      # Bridge for internal traffic
      auto vmbr1
      iface vmbr1 inet static
              address 10.0.0.1/24
              bridge_ports none
              bridge_stp off
              bridge_fd 0
              post-up    iptables -t nat -A POSTROUTING -s '10.0.0.0/24' -o enp6s0 -j MASQUERADE
              post-down  iptables -t nat -D POSTROUTING -s '10.0.0.0/24' -o enp6s0 -j MASQUERADE
      iface vmbr1 inet6 static
              address 2a01:4f8:212:3203::3/64
      ```

   6. Add the compass to the `/etc/hosts` file:

      ```hosts
      # Public
      136.243.130.114       aarde.jrzutphen.dev        aarde
      2a01:4f8:212:3203::1  aarde.jrzutphen.dev        aarde
      136.243.130.109       kompas.aarde.jrzutphen.dev kompas.aarde
      2a01:4f8:212:3203::3  kompas.aarde.jrzutphen.dev kompas.aarde

      # Internal
      127.0.0.1             localhost.localdomain localhost
      ::1                   ip6-localhost ip6-loopback
      fe00::0               ip6-localnet
      ff00::0               ip6-mcastprefix
      ff02::1               ip6-allnodes
      ff02::2               ip6-allrouters
      ff02::3               ip6-allhosts
      ```

   7. Edit `/etc/pve/storage.cfg`:

      ```conf
      dir: local
         path /var/lib/vz
         content iso,vztmpl,backup
         prune-backups keep-all=1

      lvmthin: data
         thinpool data
         vgname pve
         content rootdir,images
      ```

   8. Reboot the system: `reboot`

3. Configure SSL: (not necessary anymore, since we're using Traefik now)

   1. Go to `https://136.243.130.114:8006` and log in with the root user
   2. Go to `Datacenter` → `ACME`
   3. (opt) Add a new ACME account with the name `jrzutphen` and the email `
   4. Add a new Challenge Plugin with ID `jrzutphen-hetzner`, DNS API `hetzner` and an API token retrieved from [the DNS Console](https://dns.hetzner.com/settings/api-token).

      API Data should be in the format `HETZNER_Token="abcdefgh12345678"`.

   5. Now go to `hart` → `System` → `Certificates` and add the `hart.jrzutphen.dev` domain using the `jrzutphen-hetzner` plugin
   6. Order a certificate and wait for it to be issued
   7. You should now be able to access the Proxmox VE web interface using `https://hart.jrzutphen.dev:8006`

4. Secure the system:

   1. Create a lower-privileged user:

      ```bash
      adduser tech
      adduser tech sudo
      passwd root --lock
      pveum user add tech@pam -email techniek@jrzutphen.nl
      ```

   2. Configure SSH to be more secure: in `/etc/ssh/sshd_config`:

      ```conf
      Port 2023

      PermitRootLogin no
      AllowUsers tech
      MaxAuthTries 2

      AuthenticationMethods publickey,keyboard-interactive

      PubkeyAuthentication yes
      AuthorizedKeysFile   .ssh/authorized_keys

      PasswordAuthentication no
      PermitEmptyPasswords no

      KbdInteractiveAuthentication yes
      UsePAM yes

      AllowAgentForwarding no
      AllowTcpForwarding no
      X11Forwarding no
      ClientAliveInterval 60
      ClientAliveCountMax 3
      ```

   3. Generate 2FA tokens for the `tech` user:

      ```bash
      sudo apt install libpam-google-authenticator
      google-authenticator
      ```

   4. Configure the PAM module in `/etc/pam.d/sshd`:

      ```conf
      # Standard Un*x authentication.
      #@include common-auth

      # Two-factor authentication
      auth       required     pam_google_authenticator.so
      ```

   5. Install and configure `fail2ban`:

      ```bash
      sudo apt install fail2ban
      sudo cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local
      sudo systemctl enable fail2ban
      ```

      In `/etc/fail2ban/jail.local`:

      ```conf
      [sshd]
      enabled = true
      mode    = aggressive
      port    = 2023
      logpath = %(sshd_log)s
      backend = systemd

      # Add the following lines to the end of the file
      [proxmox]
      enabled  = true
      port     = https,http,8006
      filter   = proxmox
      backend  = systemd
      maxretry = 3
      findtime = 2d
      bantime  = 1h
      ```

      Create a new filter in `/etc/fail2ban/filter.d/proxmox.conf`:

      ```conf
      [Definition]
      failregex = pvedaemon\[.*authentication failure; rhost=<HOST> user=.* msg=.*
      ignoreregex =
      ```

      Forward logs to the syslog:

      ```bash
      sudo sed -i 's/#ForwardToSyslog=yes/ForwardToSyslog=yes/' /etc/systemd/journald.conf
      sudo systemctl restart systemd-journald
      ```

      Then run `sudo systemctl start fail2ban`

   6. Assign `tech` to the admin group in Proxmox

      ```bash
      sudo pveum group add admins
      sudo pveum acl modify / -group admins -role Administrator
      sudo pveum user modify tech@pam -group admins
      ```

5. Set up Traefik & Portainer

   1. Download the ubuntu-23.10 template
   2. Create a new LXC Container with the following settings:
      - Hostname: `kompas`
      - Template: `ubuntu-23.10`
      - Root disk: `32` GiB
      - CPU cores: `4`
      - Memory: `16384` MiB
      - Swap: `4096` MiB
      - Network:
        - IPv4: `Static`
        - IPv4/CIDR: `136.243.130.109/32`
        - IPv4 Gateway: `136.243.130.114`
        - IPv6: `Static`
        - IPv6/CIDR: `2a01:4f8:212:3203::4/64`
        - IPv6 Gateway: `2a01:4f8:212:3203::2`
   3. Add another network device with the following settings:
      - Name: `eth1`
      - Bridge: `vmbr1`
      - IPv4: `Static`
      - IPv4/CIDR: `10.0.0.2/24`
      - IPv4 Gateway: `10.0.0.1`
      - IPv6: `Static`
      - IPv6/CIDR: `2a01:4f8:212:3203::5/64`
      - IPv6 Gateway: `2a01:4f8:212:3203::3`
   4. In the LXC options, enable `keyctl` (temporarily log in as `root` to do this)
   5. Start the container and log in as `root`
   6. Configure secure access:

      ```bash
      # Create a less-privileged user
      adduser tech
      adduser tech sudo
      passwd root --lock
      ```

   7. Log out and log back in as `tech`
   8. Configure SSH to be more secure: in `/etc/ssh/sshd_config`:

      ```conf
      PermitRootLogin no
      AllowUsers tech
      MaxAuthTries 2

      AuthenticationMethods publickey,keyboard-interactive

      PubkeyAuthentication yes
      AuthorizedKeysFile .ssh/authorized_keys

      PasswordAuthentication no
      PermitEmptyPasswords no

      KbdInteractiveAuthentication yes

      UsePAM yes

      AllowAgentForwarding no
      AllowTcpForwarding no
      X11Forwarding no
      ClientAliveInterval 60
      ClientAliveCountMax 3
      ```

      And in `/etc/systemd/system/ssh.socket.d/listen.conf`:

      ```conf
      [Socket]
      ListenStream=
      ListenStream=2023
      ```

      Make sure to add your public key to `~/.ssh/authorized_keys`

   9. Configure 2FA:

      ```bash
      sudo apt install libpam-google-authenticator
      google-authenticator # Enter whatever
      ```

      Then edit the `~/.google_authenticator` to match the contents of the Proxmox host

   10. Configure the PAM module in `/etc/pam.d/sshd`:

       ```conf
       # Standard Un*x authentication.
       #@include common-auth

       # Two-factor authentication.
       auth       required     pam_google_authenticator.so
       ```

   11. Install and configure `fail2ban`:

       ```bash
       sudo apt install fail2ban
       sudo cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local
       sudo systemctl enable fail2ban
       ```

       In `/etc/fail2ban/jail.local`:

       ```conf
       [sshd]
       enabled = true
       mode    = aggressive
       port    = 2023
       logpath = %(sshd_log)s
       backend = systemd
       ```

       Then run `sudo systemctl start fail2ban`

   12. Install Docker:

       ```bash
       sudo apt update
       sudo apt install curl
       sudo install -m 0755 -d /etc/apt/keyrings
       sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
       sudo chmod a+r /etc/apt/keyrings/docker.asc
       echo \
         "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
         $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
         sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
       sudo apt update
       sudo apt install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
       sudo adduser tech docker
       ```

   13. Install Traefik:

       ```bash
       mkdir traefik/data --parents
       cd traefik/data
       touch acme.json
       chmod 600 acme.json
       touch config.yaml
       docker network create traefik-proxy
       ```

       Create `traefik.yaml`:

       ```yaml
       api:
         dashboard: true
         debug: true
       entryPoints:
         http:
           address: ":80"
           http:
             redirections:
               entryPoint:
                 to: https
                 scheme: https
         https:
           address: ":443"
       serversTransport:
         insecureSkipVerify: true
       providers:
         docker:
           endpoint: "unix:///var/run/docker.sock"
           exposedByDefault: false
         file:
           filename: /config.yaml
       certificatesResolvers:
         hetzner:
           acme:
             email: techniek@jrzutphen.nl
             storage: acme.json
             dnsChallenge:
               provider: hetzner
       ```

       Create `docker-compose.yaml`:

       ```yaml

       ```

6. Create a new network device in Proxmox with the following settings:
   - Name: `eth1`
   - MAC address: `00:50:56:00:91:F8`
   - Bridge: `vmbr1`
   - IPv4: `Static`
   - IPv4/CIDR: `136.243.130.109/26`
   - IPv4 Gateway: `136.243.130.65`
   - IPv6: `Static`
   - IPv6/CIDR: `2a01:4f8:212:3203::5/64`
   - IPv6 Gateway: `2a01:4f8:212:3203::4`

## Guest configuration

`/etc/network/interfaces`:

```conf
auto lo

iface lo inet loopback

iface lo inet6 loopback


auto ens18

iface ens18 inet static
    address 10.0.0.2/24
    gateway 10.0.0.1

iface ens18 inet6 static
    address 2a01:4f8:212:3203::4/64
    gateway 2a01:4f8:212:3203::3
```

## Firewall configuration

### Inbound

| Name            | Description                       | Version | Protocol | Source IP | Destination IP | Source port | Destination port | TCP flags | Action |
| :-------------- | :-------------------------------- | :------ | :------- | :-------- | :------------- | :---------- | :--------------- | :-------- | :----- |
| icmp            | Allow ICMP                        | IPv4    | ICMP     |           |                |             |                  |           | ACCEPT |
| icmp            | Allow ICMP                        | IPv6    | ICMP     |           |                |             |                  |           | ACCEPT |
| ssh             | Allow SSH                         | IPv4    | TCP      |           |                |             | 22               |           | ACCEPT |
| ssh             | Allow SSH                         | IPv6    | TCP      |           |                |             | 22               |           | ACCEPT |
| tcp-established | Allow established TCP connections | IPv4    | TCP      |           |                |             | 32768-65535      | ACK       | ACCEPT |
| tcp-established | Allow established TCP connections | IPv6    | TCP      |           |                |             | 32768-65535      | ACK       | ACCEPT |
| pve             | Allow Proxmox VE                  | IPv4    | TCP      |           |                |             | 8006             |           | ACCEPT |
| pve             | Allow Proxmox VE                  | IPv6    | TCP      |           |                |             | 8006             |           | ACCEPT |

### Outbound

| Name      | Description       | Version | Protocol | Source IP | Destination IP | Source port | Destination port | TCP flags | Action |
| :-------- | :---------------- | :------ | :------- | :-------- | :------------- | :---------- | :--------------- | :-------- | :----- |
| allow-all | Allow all traffic | \*      | \*       |           |                |             |                  |           | ACCEPT |

## Cool utilities

```bash
apt install bmon
apt install bridge-utils
```

Mosh

`systemctl set-default multi-user.target`
