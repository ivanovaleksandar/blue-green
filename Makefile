PROJECT_ID ?= blue-green-project
TAG ?= 0.1.0
GCP_BILLING_ACCOUNT ?= 0X0X0X-0X0X0X-0X0X0X
GKE_NAME ?= $(terraform output -raw gke_name)
GKE_LOCATION ?= $(terraform output -raw location)


all: gcp terraform docker

gcp-auth:
	gcloud auth login
	gcloud auth application-default login

gcp-project: 
	gcloud projects create ${PROJECT_ID} --name="Blue Green"

gcp-billing:
	gcloud alpha billing accounts list
	gcloud config set project ${PROJECT_ID}
	gcloud alpha billing projects link ${PROJECT_ID} --billing-account ${GCP_BILLING_ACCOUNT}
	gcloud services enable compute.googleapis.com container.googleapis.com

gcp: gcp-auth gcp-project gcp-billing

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
	docker build -t eu.gcr.io/${PROJECT_ID}/blue-green-project:${TAG} .

docker-push:
	docker push eu.gcr.io/${PROJECT_ID}/blue-green-project:${TAG}

docker: docker-build docker-push

kubernetes-creds:
	gcloud container clusters get-credentials ${GKE_NAME} --region ${GKE_LOCATION} --project ${PROJECT_ID}

destroy: 
	gcloud projects delete ${PROJECT_ID}

.PHONY: gcp terraform docker destroy