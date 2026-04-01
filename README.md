# Self-Checkout Infrastructure

Docker Compose setup for running the self-checkout services locally or in a server environment.

Related parts of the project:
- Backend: `https://github.com/KamilGrundas/self-checkout-backend`
- Client: `https://github.com/KamilGrundas/self-checkout-client`
- ML service: `https://github.com/KamilGrundas/self-checkout-ml`

## Included Services

- PostgreSQL
- MinIO
- backend container
- ml container
- Adminer
- optional Traefik and local development helpers

## Compose Files

- `compose.yml` - base stack
- `compose.override.yml` - local development overrides
- `compose.traefik.yml` - Traefik-enabled variant

## Minimal `.env`

```env
STACK_NAME=self-checkout
DOMAIN=localhost
ENVIRONMENT=local
FRONTEND_HOST=http://localhost:3000
BACKEND_CORS_ORIGINS=["http://localhost:3000"]

DOCKER_IMAGE_BACKEND=self-checkout-backend
DOCKER_IMAGE_ML=self-checkout-ml
TAG=latest

POSTGRES_SERVER=db
POSTGRES_PORT=5432
POSTGRES_DB=app
POSTGRES_USER=postgres
POSTGRES_PASSWORD=change-me

SECRET_KEY=change-me
FIRST_SUPERUSER=admin@example.com
FIRST_SUPERUSER_PASSWORD=change-me
PROJECT_NAME=self-checkout

MINIO_ENDPOINT=minio:9000
MINIO_ACCESS_KEY=minioadmin
MINIO_SECRET_KEY=minioadmin
MINIO_BUCKET_NAME=product-images
ML_MINIO_BUCKET_NAME=session-images
MINIO_PUBLIC_URL=http://localhost:9000
MINIO_USE_SSL=false
```

## Run Locally

Base stack:

```bash
docker compose up --build
```

Local development variant:

```bash
docker compose -f compose.yml -f compose.override.yml up --build
```

This starts the backend API, ML API, PostgreSQL, MinIO, and Adminer for local development.

## Local Endpoints

- backend: `http://127.0.0.1:8000`
- ml api: `http://127.0.0.1:8001`
- postgres: `127.0.0.1:5432`
- adminer: `http://127.0.0.1:8080`
- minio api: `http://127.0.0.1:9000`
- minio console: `http://127.0.0.1:9001`

## Notes

- The backend stores product images in `MINIO_BUCKET_NAME`.
- The ML service stores checkout session snapshots in `ML_MINIO_BUCKET_NAME`.
- The client should point `API_BASE_URL` to the backend and `ML_API_BASE_URL` to the ML service.
