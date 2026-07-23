# Self-Checkout Infrastructure

Minimal Docker Compose setup for local development.

Related parts of the project:
- Backend: `https://github.com/KamilGrundas/self-checkout-backend`
- Admin panel: `../self-checkout-admin`
- Client: `https://github.com/KamilGrundas/self-checkout-client`
- ML service: `https://github.com/KamilGrundas/self-checkout-ml`

## Services

Default stack:
- PostgreSQL
- MinIO
- MinIO bucket bootstrap
- backend
- admin panel
- ml

Optional `ml-dev` stack:
- MLflow
- Label Studio

## Minimal `.env`

```env
FRONTEND_HOST=http://localhost:5173
VITE_API_URL=http://localhost:8000
ENVIRONMENT=local
BACKEND_CORS_ORIGINS=http://localhost,http://localhost:5173,https://localhost,https://localhost:5173

SECRET_KEY=changethis
FIRST_SUPERUSER=admin@example.com
FIRST_SUPERUSER_PASSWORD=changethis

SMTP_HOST=
SMTP_USER=
SMTP_PASSWORD=
EMAILS_FROM_EMAIL=info@example.com
SMTP_TLS=True
SMTP_SSL=False
SMTP_PORT=587

POSTGRES_PORT=5432
POSTGRES_DB=app
POSTGRES_USER=postgres
POSTGRES_PASSWORD=changethis

SENTRY_DSN=

MINIO_ENDPOINT=minio:9000
MINIO_ACCESS_KEY=minioadmin
MINIO_SECRET_KEY=minioadmin
MINIO_BUCKET_NAME=product-images
ML_MINIO_SHELF_BUCKET_NAME=session-images
ML_MINIO_SCALE_BUCKET_NAME=scale-images
ML_MINIO_EXTERNAL_BUCKET_NAME=uploaded-images
ML_MINIO_TRAINING_BUCKET_NAME=training-data
ML_MINIO_LABELSTUDIO_EXPORT_BUCKET_NAME=labelstudio-exports
MINIO_PUBLIC_URL=http://localhost:9000
MINIO_USE_SSL=false

MLFLOW_TRACKING_URI=http://mlflow:5000
MLFLOW_SERVER_ALLOWED_HOSTS=mlflow:5000,localhost:5000,localhost:5002,127.0.0.1:5000,127.0.0.1:5002
MLFLOW_REGISTERED_MODEL_NAME=self-checkout-classifier
MLFLOW_SHELF_EXPERIMENT_NAME=self-checkout-shelf-classifier
MLFLOW_SHELF_MODEL_NAME=self-checkout-shelf-classifier
MODEL_CACHE_DIR=.cache/model_store
LABEL_STUDIO_URL=http://label-studio:8080
LABEL_STUDIO_USERNAME=admin@example.com
LABEL_STUDIO_PASSWORD=changethis
LABEL_STUDIO_API_KEY=changethis-api-key
LABEL_STUDIO_SCALE_PROJECT_TITLE=scale-products
LABEL_STUDIO_SHELF_PROJECT_TITLE=shelf-products
LABEL_STUDIO_EXTERNAL_PROJECT_TITLE=external-products

DOCKER_IMAGE_BACKEND=backend
DOCKER_IMAGE_ADMIN=admin
DOCKER_IMAGE_ML=ml
TAG=dev
```

## Run

Default stack:

```bash
./scripts/up.sh
```

`ml-dev` stack:

```bash
./scripts/up-ml-dev.sh
```

`./scripts/up.sh` starts the default stack and then stops the optional
`ml-dev` services if they are already running.

## Container version policy

External images use an explicit patch or release tag plus an immutable
multi-architecture manifest digest. Application images require an explicit
`TAG`; `dev` is only the local build tag. Production must continue to use an
approved immutable release tag or digest through the controlled deployment
procedure.

PostgreSQL major upgrades are intentionally excluded from routine image
refreshes because they require a separate data migration and rollback plan.

The MinIO Community Edition repository and official image distribution are no
longer maintained. The official image is pinned to its final published image;
do not replace it with a third-party rebuild. Plan a separate object-storage
migration:

1. compare actively maintained S3-compatible candidates (SeaweedFS, Garage,
   Ceph RGW, or a managed S3 service) against the exact API calls used by the
   backend, ML service, and Label Studio;
2. validate bucket creation, path-style addressing, multipart uploads, object
   metadata, presigned/public URLs, and Label Studio storage integration;
3. create and checksum a full export of every configured bucket;
4. dual-write or freeze writes, copy data, compare object counts and hashes,
   then switch endpoints;
5. retain the MinIO volume read-only until the rollback window closes.

Re-evaluate immediately when a security issue affects the pinned MinIO release.
Do not perform this data migration as an image-only update.

## Local Endpoints

- backend: `http://127.0.0.1:8000`
- admin panel: `http://127.0.0.1:5173`
- ml api: `http://127.0.0.1:8001`
- postgres: `127.0.0.1:5432`
- minio api: `http://127.0.0.1:9000`
- minio console: `http://127.0.0.1:9001`
- mlflow: `http://127.0.0.1:5002` in `ml-dev`
- label studio: `http://127.0.0.1:8080` in `ml-dev`

## Notes

- The backend stores product images in `MINIO_BUCKET_NAME`.
- The ML service stores raw shelf snapshots in `ML_MINIO_SHELF_BUCKET_NAME`.
- The ML service stores raw scale images in `ML_MINIO_SCALE_BUCKET_NAME`.
- The ML service stores manually uploaded images in `ML_MINIO_EXTERNAL_BUCKET_NAME`.
- `build_dataset.py` uploads reviewed training releases to `ML_MINIO_TRAINING_BUCKET_NAME`.
- Label Studio writes raw export snapshots to `ML_MINIO_LABELSTUDIO_EXPORT_BUCKET_NAME`.
- The ML service keeps a persistent local model cache in the `ml-model-cache` volume.
- MLflow and Label Studio are optional and should be started only when you need training, labeling, model registration, or manual model refresh.
- MLflow 3.5+ validates Host headers, so `MLFLOW_SERVER_ALLOWED_HOSTS` must include both `mlflow:5000` and local host variants.
- `LABEL_STUDIO_API_KEY` must be a current personal access token, not a legacy user token.
- The ML service exchanges `LABEL_STUDIO_API_KEY` for a short-lived access token through `/api/token/refresh`.
- Label Studio sync (project creation, MinIO bucket attachment) is triggered via `POST /api/v1/label-studio/sync` on the ML service.
- The sync endpoint returns 503 if Label Studio is unreachable.
