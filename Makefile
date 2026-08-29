TERRAFORM_DIR := infrastructure/terraform
ANSIBLE_DIR := infrastructure/ansible

.PHONY: bootstrap bootstrap-status bootstrap-destroy bootstrap-cleanup-session destroy-all init image image-refresh plan apply destroy inventory terraform-validate ansible-inventory ansible-syntax k3s

bootstrap:
	./scripts/bootstrap-libvirt.sh apply

bootstrap-status:
	./scripts/bootstrap-libvirt.sh status

bootstrap-destroy:
	./scripts/bootstrap-libvirt.sh destroy

bootstrap-cleanup-session:
	./scripts/bootstrap-libvirt.sh cleanup-session-artifact

init:
	terraform -chdir=$(TERRAFORM_DIR) init

image:
	./scripts/download-ubuntu-cloud-image.sh

image-refresh:
	./scripts/download-ubuntu-cloud-image.sh --refresh

plan:
	terraform -chdir=$(TERRAFORM_DIR) plan

apply:
	terraform -chdir=$(TERRAFORM_DIR) apply

destroy:
	terraform -chdir=$(TERRAFORM_DIR) destroy

destroy-all: destroy bootstrap-destroy

inventory:
	./scripts/generate-ansible-inventory.sh

terraform-validate:
	terraform -chdir=$(TERRAFORM_DIR) fmt -check
	terraform -chdir=$(TERRAFORM_DIR) validate

ansible-inventory:
	ANSIBLE_CONFIG=$(abspath $(ANSIBLE_DIR)/ansible.cfg) ansible-inventory --list

ansible-syntax: inventory
	ANSIBLE_CONFIG=$(abspath $(ANSIBLE_DIR)/ansible.cfg) ansible-playbook $(abspath $(ANSIBLE_DIR)/playbooks/bootstrap-k3s.yaml) --syntax-check

k3s: inventory
	ANSIBLE_CONFIG=$(abspath $(ANSIBLE_DIR)/ansible.cfg) ansible-playbook $(abspath $(ANSIBLE_DIR)/playbooks/bootstrap-k3s.yaml)
	./scripts/bootstrap-libvirt.sh apply
