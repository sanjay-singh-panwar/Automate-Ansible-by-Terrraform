resource "local_file" "inventory" {
  content = templatefile("${path.module}/inventory.tpl", {
    docker_ip = module.docker_instance.public_ip
    nginx_ip  = module.nginx_instance.public_ip
  })
  filename = "${path.module}/inventory.ini"
}

resource "null_resource" "clone_repo" {
  provisioner "local-exec" {
    command = <<EOT
      rm -rf ./ansible
      git clone https://github.com/sanjay-singh-panwar/Sanjay-portfolio.git ./ansible
    EOT
  }
}

resource "null_resource" "ansible_provision" {
  depends_on = [module.docker_instance, module.nginx_instance, local_file.inventory]

  provisioner "local-exec" {
    command = "ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -i inventory.ini ansible/main.yml --private-key ${path.module}/terraform-ansible-key.pem -u ubuntu"
  }
}
