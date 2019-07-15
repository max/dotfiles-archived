provider "digitalocean" {}

variable "region" {
  default = "sfo2"
}

resource "digitalocean_volume" "dev" {
  name                    = "dev"
  region                  = "${var.region}"
  size                    = 100
  initial_filesystem_type = "ext4"
  description             = "volume for dev"

  lifecycle {
    prevent_destroy = true
  }
}

resource "digitalocean_droplet" "dev" {
  name               = "dev"
  image              = "ubuntu-19-04-x64"
  size               = "s-4vcpu-8gb"
  region             = "${var.region}"
  private_networking = true
  backups            = true
  ipv6               = true
  ssh_keys           = [25043353] # doctl compute ssh-key list
  volume_ids         = ["${digitalocean_volume.dev.id}"]

  provisioner "file" {
    source      = "bootstrap.sh"
    destination = "/tmp/bootstrap.sh"

    connection {
      type        = "ssh"
      host        = self.ipv4_address
      private_key = "${file("~/.ssh/id_rsa")}"
      user        = "root"
      timeout     = "2m"
    }
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/bootstrap.sh",
      "/tmp/bootstrap.sh initialize",
    ]

    connection {
      type        = "ssh"
      host        = self.ipv4_address
      private_key = "${file("~/.ssh/id_rsa")}"
      user        = "root"
      timeout     = "2m"
    }
  }
}

resource "digitalocean_firewall" "dev" {
  name = "dev"

  droplet_ids = ["${digitalocean_droplet.dev.id}"]

  inbound_rule {
    protocol         = "tcp"
    port_range       = "22"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }

  inbound_rule {
    protocol         = "udp"
    port_range       = "60000-60010"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }

  outbound_rule {
    protocol              = "tcp"
    port_range            = "1-65535"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }

  outbound_rule {
    protocol              = "udp"
    port_range            = "1-65535"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }

  outbound_rule {
    protocol              = "icmp"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }
}

output "public_ip" {
  value = "${digitalocean_droplet.dev.ipv4_address}"
}
