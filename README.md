# Blue Green Deployment workflow

This repository covers one of the many ways of doing a blue green type of deployments. It uses Terraform to provision resources in GCP, Kubernetes for running the workload, Flux for providing a continuous pull based deployment (known as GitOps deployment), Makefile for easy bootstrapping and a tiny golang app.

NOTE: To set the infrastructure, you will need to have a GCP account set up and the needed permissions to enable billing for the project that is going to be created. This means that *charges will apply*. 

## Prerequisites

In order to run this, you need to have the follwing tools installed:
- (Terraform)[https://learn.hashicorp.com/tutorials/terraform/install-cli]
- (GCloud util)[https://cloud.google.com/sdk/docs/install]
- (Kubectl)[https://kubernetes.io/docs/tasks/tools/]
- (Helm)[https://helm.sh/docs/intro/install/]
- (Kustomize)[https://kubectl.docs.kubernetes.io/installation/kustomize/]
- (Docker)[https://docs.docker.com/get-docker/]
- (Flux)[https://fluxcd.io/docs/installation/]
- (wrk)[https://github.com/wg/wrk]
- (Optional: if using Windows)(Make)[https://stackoverflow.com/a/32127632/7105071] 

## Bootstrap project

First, fork and then clone this repository. 

Make sure you change these variables in the before continuing.

```
export GITHUB_USER=gh-user # Your GitHub username
export GITHUB_TOKEN=ghp_xxxxxxxxxxxxxxxxxxxxxxxxx # Your Personal GitHub Access Token
export PROJECT_ID=blue-green-project-123456 # A Globally unique name for the GCP project 
export GCP_BILLING_ACCOUNT=0X0X0X-0X0X0X-0X0X0X # A GCP Billing account for enabling billing for your project
```

Also, login to GCP:
```
gcloud auth login
gcloud auth application-default login
```

Now, just execute: 
```
make
```

This should perform the following actions:
- Create a GCP project & enable billing for the project
- Create infrastructure
- Create and push Docker image to GCP registry
- Change config for newly built image
- Grab Kubeconfig 
- Install Flux in the cluster

Some changes were done in your local repository. Now, commit all these changes and push them to master. This will trigger FLux to sync the new changes and apply them in the cluster.

You can confirm that everything is working:
```
make test
```

## Switching route 

As we can see, testing the endpoint shows us that we are currently viewing the blue deployment. To start pointing to the green deployment, we need to update the route in the kubernetes ingress resource in `deploy/ingress.yaml`, from:
```
.....
backend:
    service:
    name: blue-deploy
    port: 
        number: 80
.....
```
to this:
```
.....
backend:
    service:
    name: green-deploy
    port: 
        number: 80
.....
```

Commit the newly made changes and push to master. Flux will take a moment before it synchornizes the new changes.

Now, confirm that we are pointing to the green deployment:
```
make test
```

## Introduce changes in the app

Now that we are pointing to the green deployment, we can introduce changes to the app and deploy them in the blue deployment. This way, we are making sure that no incomming traffic is affected by it. These changes will have an impact only when we switch the ingress resource to point again to the blue deployment.

Ok, lets first introduce change is the app:
```
sed -i -e 's/This is the %s deployment/Hello, this is the %s deployment/g' main.go
```

Create a new image with a new tag and push it:
```
export TAG=0.2.0
make docker
make docker-tag-blue
```

Commit and push the changes.

Testing the endpoint with `make test` shows us that even though we created a new image and updated the blue deployment, the changes are still not visible. As we mentioned previously, the changes will only have an effect when we swithc the ingress resource to point to the new blue deployment.

```
.....
backend:
    service:
    name: green-deploy
    port: 
        number: 80
.....
```
to this:
```
.....
backend:
    service:
    name: blue-deploy
    port: 
        number: 80
.....
```

Commit and push the changes. Wait few moments for Flux to syncronize the changes. 

Confirm that it works:
```
make test
```

Congrats. That should be it. You have successfully went through the blue green type of deployment.

## Delete everything

After you tested everything, you can destroy the project (and make sure you are not charged anymore)
```
make destroy
```
