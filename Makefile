TAG          ?= 0.1.0
REPO_NAME    ?= $(shell basename $(shell git rev-parse --show-toplevel))
GKE_NAME     ?= $(shell terraform output -raw gke_name)
GKE_LOCATION ?= $(shell terraform output -raw location)
LB_IP        ?= $(shell terraform output -raw lb_address)

all: gcp terraform docker docker-tag-all kubernetes-creds flux-install

gcp-auth:
	gcloud auth login
	gcloud auth application-default login

gcp-project: 
	gcloud projects create ${PROJECT_ID} --name="Blue Green"

gcp-set-project:
	gcloud config set project ${PROJECT_ID}

gcp-billing:
	gcloud alpha billing accounts list
	gcloud alpha billing projects link ${PROJECT_ID} --billing-account ${GCP_BILLING_ACCOUNT}
	gcloud services enable compute.googleapis.com container.googleapis.com

gcp: gcp-project gcp-set-project gcp-billing

terraform-init:
	terraform init

terrorm-plan:
	terraform plan -var "project_id=${PROJECT_ID}"

terrorm-apply:
	terraform apply -var "project_id=${PROJECT_ID}" -auto-approve

terraform-destroy:
	terraform destroy -var "project_id=${PROJECT_ID}" -auto-approve

terraform: terraform-init terrorm-apply

docker-build:
	docker build -t eu.gcr.io/${PROJECT_ID}/blue-green-app:${TAG} .

docker-push:
	docker push eu.gcr.io/${PROJECT_ID}/blue-green-app:${TAG}

docker: docker-build docker-push

docker-tag-blue:
	cd deploy/blue-app
	kustomize edit set image blue-green=eu.gcr.io/${PROJECT_ID}/blue-green-app:${TAG}

docker-tag-green:
	cd deploy/green-app
	kustomize edit set image blue-green=eu.gcr.io/${PROJECT_ID}/blue-green-app:${TAG}

docker-tag-all: docker-tag-blue docker-tag-green

kubernetes-creds:
	gcloud container clusters get-credentials ${GKE_NAME} --region ${GKE_LOCATION} --project ${PROJECT_ID}

flux-install:
	flux bootstrap github --owner=${GITHUB_USER} --repository=${REPO_NAME} --path=./deploy --branch=master --personal

test: 
	curl --header "Host: blue-green.example.com" http://${LB_IP}

test-conn:
	wrk --duration 10m --header "Host: blue-green.example.com" http://${LB_IP}

destroy: 
	gcloud projects delete ${PROJECT_ID}


.PHONY: all gcp terraform docker destroy
