## Overview

As an avid fan of Spotify's Discover Weekly playlist, I always wanted to have a scheduled, automated, self-controlled lean and cheap way of backing up the weekly generated tracks. There are different plugins to achieve the same result and integrate much more easily, so bear in mind that this is a slightly overengineered solution for cloud infrastructure enthusiasts.

This project uses

- python (including the [spotipy](https://spotipy.readthedocs.io/) package) to back up Spotify playlist tracks by copying them into another playlist,
- serverless Google cloud infrastructure (Cloud functions, Cloud scheduler, Cloud storage, Secret manager, etc.) to schedule and run the code,
- terraform to manage the infrastructure in code

The cloud function which executes the script is [idempotent](https://cloud.google.com/blog/products/serverless/cloud-functions-pro-tips-building-idempotent-functions?hl=en), i.e. it "can be applied multiple times without changing the result beyond the initial application" (see [wiki/Idempotence](https://en.wikipedia.org/wiki/Idempotence)).

In case you are not interested in backing up Spotify playlists or Spotify's Discover Weekly, this project may be of interest if you want to learn how to automate and schedule a python function call using cloud infrastructure and infrastructure as code.

## Prerequisites

Existing Google Cloud project and terraform (>=v1.3.4).

## Setup

### 0 tl;dr

Short summary of what follows below in more detail:

1. Create Spotify app in Spotify Developer Dashboard to create credentials and identify playlist IDs.
1. Apply terraform
1. Run auth script to create and store refresh token, this equips the cloud function with access to Spotify account.
1. Configure Github for CI/CD
1. Test cloud function via curl

### 1 Setting up Spotify

#### 1a Authentication

As a first step, we need to create an app in the [Spotify Developer dashboard](https://developer.spotify.com/dashboard/applications). This will provide a client ID and client secret.
To modify our private playlist, we will need to authenticate via the [authorization code flow](https://developer.spotify.com/documentation/general/guides/authorization/code-flow/).
For this we also need to set up a redirect URI to, which we can achieve via `Edit settings`. In our case, `http://localhost:8080` will work to run the authentication locally.

```
export SPOTIFY_CLIENT_ID="{your-spotify-client-id}"
export SPOTIFY_CLIENT_SECRET="{your-spotify-client-secret}"
export SPOTIFY_REDIRECT_URI="{your-spotify-redirect-uri}"
```

The authorization flow will provide us with access and refresh tokens, which we have to store securely. For this we can use Google Secret Manager. Via the refresh token, the `spotipy` library will be able to request new access tokens, which are usually valid for 1 hour. To achieve all this we will use a little helper script (see step 3).

#### 1b Playlists

Moreover, we need to find out the IDs of our source playlist (Discover Weekly) as well as the destination playlist we want to insert the tracks into. You can get the ID either through the web app or within the installed app via right-clicking on the playlist and then `Share -> Copy link to playlist`.
The link looks like this: `https://open.spotify.com/playlist/{id}`.

```
export SOURCE_PLAYLIST_ID="{your-source-playlist-id}"
export DESTINATION_PLAYLIST_ID="{your-destination-playlist-secret}"
```

### 2 Creating the infrastructure

We can then create our infrastructure via terraform:

```
cd terraform
terraform plan
terraform apply
```

After roughly two minutes the infrastructure should be created:

```
Apply complete! Resources: 20 added, 0 changed, 0 destroyed.

Outputs:

cloud_function_bucket_name = "dw-saver-54a6"
cloud_function_name = "dw-saver"
cloud_function_secret_id = "dw-saver-token"
cloud_function_service_account = "dw-saver@{your-project-id}.iam.gserviceaccount.com"
cloud_function_url = "https://europe-west3-{your-project-id}.cloudfunctions.net/dw-saver"
deployment_service_account = "dw-saver-deployment@{your-project-id}.iam.gserviceaccount.com"
workload_identity_provider = "projects/{your-num-project-id}/locations/global/workloadIdentityPools/github-pool/providers/github-provider"
```

Straight after creation, the cloud function will not work properly yet, since we have not provided spotify client ID and secret nor the refresh and access token. We will generate these in the next step.

#### Optional: Importing already existing resources

If we have created the infrastructure before, we might want to import previously created long-living resources like the Workload Identity pool and provider beforehand:

```
terraform import google_iam_workload_identity_pool.deployment github-pool
terraform import google_iam_workload_identity_pool_provider.deployment github-pool/github-provider
terraform apply ...
```

### 3 Running the Spotify authorization code flow

With all environment variables in place locally, we can use our helper script to generate the refresh and access token and store them in Google Secret Manager (making use of the `GoogleSecretManagerCacheHandler` class):

```
SPOTIFY_CLIENT_ID=$SPOTIFY_CLIENT_ID \
  SPOTIFY_CLIENT_SECRET=$SPOTIFY_CLIENT_SECRET \
  SPOTIFY_REDIRECT_URI=$SPOTIFY_REDIRECT_URI \
  GCP_PROJECT_ID=$GCP_PROJECT_ID \
  GCP_SECRET_ID=$GCP_SECRET_ID \
  python app/auth.py
```

We have still not provided Spotify access to our cloud function, which we will do in the next step.

### 4 Setting up CI/CD via Github actions

Since we plan to maintain this codebase in a serverless fashion, we can use Github actions to deploy and test the code and infrastructure.

To grant our deployment access to Spotify we have to add the Spotify credentials `SPOTIFY_CLIENT_ID, SPOTIFY_CLIENT_SECRET, SPOTIFY_REDIRECT_URI` to the repo secrets via `Settings -> Secrets -> Actions`.

To make the deployment work via Github Actions we need to specifcy a few more environment variables.
We can read these from the corresponding `terraform` outputs after we have run the `terraform apply`:

```
Outputs:

cloud_function_bucket_name = "dw-saver-54a6"
cloud_function_name = "dw-saver"
cloud_function_secret_id = "dw-saver-token"
cloud_function_service_account = "dw-saver@{your-project-id}.iam.gserviceaccount.com"
cloud_function_url = "https://europe-west3-{your-project-id}.cloudfunctions.net/dw-saver"
deployment_service_account = "dw-saver-deployment@{your-project-id}.iam.gserviceaccount.com"
workload_identity_provider = "projects/{your-num-project-id}/locations/global/workloadIdentityPools/github-pool/providers/github-provider"
```

Alternatively, we can fetch these programmatically via the `terraform output` command:

```
cd terraform
export CLOUD_FUNCTION_URL=$(terraform output -raw cloud_function_url)
export CLOUD_FUNCTION_BUCKET_NAME=$(terraform output -raw cloud_function_bucket_name)
export CLOUD_FUNCTION_SERVICE_ACCOUNT=$(terraform output -raw cloud_function_secret_id)
export CLOUD_FUNCTION_SECRET_ID=$(terraform output -raw cloud_function_service_account)
...
```

If we add these to the Github [deploy](.github/workflows/deploy.yml) workflow we can use Github actions to do the deployment using `gcloud CLI` and eventually test it.


### 5 Testing the cloud function

We can ping the cloud function endpoint and should receive an `OK`:

```
export CLOUD_FUNCTION_URL=$(cd terraform && terraform output -raw cloud_function_url)
curl \
  --silent \
  -X POST \
  $CLOUD_FUNCTION_URL \
  -H "Authorization: bearer $(gcloud auth print-identity-token)" \
  -H "Content-Type: application/json" \
  -d '{}'
```

## Development & testing

### 1 Testing the cloud function locally

We can test the cloud function end-to-end locally before deployment using the `functions framework`.
If we want to test the Spotify integration, we need to make sure we have access to the secret. This can be checked via

```
gcloud secrets \
  versions access latest \
  --secret=$CLOUD_FUNCTION_SECRET_ID \
  --impersonate-service-account=$CLOUD_FUNCTION_SERVICE_ACCOUNT
```

We can start the function in the background (using the ampersand)

```
pip install functions-framework
functions-framework --target copy_tracks --port 8765 &
```

and then send request via

```
curl -X POST localhost:8765 -d '{}'
```

More on this to be found in a Google blog post [How to develop and test your Cloud Functions locally](https://cloud.google.com/blog/topics/developers-practitioners/how-to-develop-and-test-your-cloud-functions-locally?hl=en)

### 2 Setting up tests

We can set up above test in a programmatic way and by mocking the relevant parts or by using dry-run functionality, again either

- by using the [functions framework](tests/test_http_integration.py) or by
- testing the [python function itself](tests/test_utils.py)

Since our cloud function is idempotent and invocations come with almost no cost, we can also run test using the real infrastructure, either by

- invoking the function locally but using the Spotify credentials from Google cloud, see [test-integration.yml](.github/workflows/deploy.yml),
- invoking the remote cloud function using the http endpoint and curl, see [deploy.yml](.github/workflows/deploy.yml)

## Teardown

### 1 Emptying the bucket

You can delete all objects in the bucket via

```
gsutil rm -a gs://${CLOUD_FUNCTION_BUCKET_NAME}/**
```

### 2 Destroying the infrastructure

We can destroy all infrastructure using a simple `terraform destroy`, but there is a drawback: Since Workload Identity pools and providers are soft-deleted and recreating them under the same name is blocked for 30 days, we may want to remove the pool and provider state first, in case we want to apply the infrastructure again:

```
cd terraform
terraform state rm google_iam_workload_identity_pool.deployment
terraform state rm google_iam_workload_identity_pool_provider.deployment
terraform destroy
```

If we do not bother, a simple `terraform destroy` will do though.

## Cost

As per 2022-12-27 the cloud infrastructure cost for Cloud Function, Cloud Storage, Cloud Scheduler are below 0.01$ per month and within the free tiers, if deployments are done moderately (few a week) and schedule is reasonable (few times a week).

Only potential cost driver are the Secrets, if multiple versions are kept active (i.e. undestroyed). Since the refresh token produces new versions regularly, versions can add up and produce [low but increasing cost](https://cloud.google.com/secret-manager/pricing) exceeding the free tier. Thus there is a method (see `_delete_old_versions` in [utils.py](app/utils.py))) to destroy old secret versions, which is invoked by default once the secret has been updated.

## Miscellaneous

- We can update the environment variables used in the cloud function deployment "in-place" (will still trigger a new deployment) via

        gcloud functions deploy \
          --region=europe-west3 \
          discover-weekly-saver \
          --update-env-vars \
          GCP_SECRET_ID=${GCP_SECRET_ID} \
          ...
- Potential improvements:
  - To make the project completely "serverless", the Terraform deployment could be moved into CI/CD, i.e. Github actions, for ex. using atlantis.
  - For full reproducability, the python code could be put into Docker. More on this to be found in another blogpost: [Building a serverless, containerized batch prediction model using Google Cloud Run, Pub/Sub, Cloud Storage and Terraform.
](https://blog.telsemeyer.com/2021/04/24/building-a-serverless-containerized-batch-prediction-model-using-google-cloud-run-pub/sub-cloud-storage-and-terraform/)
  - For better testing a staging environment could be added, and we could also use staging Spotify client or even staging playlists (as there is only one Spotify environment).
  - Since Secrets does not seem to be made for frequently changing credentials (as it is an immutable cache that adds new versions) a different cache could be used. Alternatively, the token could be encrypted using a static token and then stored in cloud storage or another key value store.
  - Secrets could also be used for the Spotify client ID and secret.

## Troubleshooting

- `NotFound: 404 Secret [projects/{your-project-id}/secrets/dw-saver-token] not found or has no versions`: You need to create the secret version first. This can be achieved by running the authentication script (see setup step 3) on your local machine.
- `Error creating Job: googleapi: Error 409: Job projects/{your-project-id}/locations/europe-west3/jobs/{something} already exists`: This may be a race condition between resources. Usually resolved by running `terraform apply` again.
- Trouble getting Workload Identity running remotely: Alternatively you can generate identity (not access!) tokens manually using the `gcloud` CLI:

        token=$(gcloud \
		   auth print-identity-token  \
		   --impersonate-service-account=$CLOUD_FUNCTION_SERVICE_ACCOUNT \
		   --include-email)

        response=$(curl \
          --silent \
          -m 310 \
          -X POST \
          $CLOUD_FUNCTION_URL \
          -H "Authorization: bearer ${token}" \
          -H "Content-Type: application/json" \
          -d '{}')

- `Error: could not handle the request`: Check cloud function logs in cloud console, usually a problem in the cloud function's python code itself.
- You can verify the token stored in Google Secret Manager using the `GoogleSecretManagerCacheHandler`:

        from utils import GoogleSecretManagerCacheHandler
        cache_handler = GoogleSecretManagerCacheHandler(project_id=GCP_PROJECT_ID, secret_id=GCP_SECRET_ID)
        cache_handler.get_cached_token()
- `End-of-central-directory signature not found.  Either this file is not..`: Set `gzip` in `google-github-actions/upload-cloud-storage` to `false` (`true` by default)
- You can restore a deleted Workload Identity pool or provider via cloud console via `IAM & Admin > Workload Identity Federation`

## Final remark

If you have any questions, feel free to add an issue or PR in this repo or ping me on [LinkedIn](https://www.linkedin.com/in/telsemeyer/).
