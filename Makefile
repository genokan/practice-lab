TERRAFORM_DIR := infrastructure/terraform
ANSIBLE_DIR := infrastructure/ansible

.PHONY: bootstrap bootstrap-status bootstrap-destroy destroy-all init image plan apply destroy inventory terraform-validate ansible-inventory

bootstrap:
	./scripts/bootstrap-libvirt.sh apply

bootstrap-status:
	./scripts/bootstrap-libvirt.sh status

bootstrap-destroy:
	./scripts/bootstrap-libvirt.sh destroy

init:
	terraform -chdir=$(TERRAFORM_DIR) init

image:
	./scripts/download-ubuntu-cloud-image.sh

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
