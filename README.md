# 🌸 Fiore — Spontaneous Event-Based Social Networking

Fiore is an open-source, event-based social media platform for spontaneous interest-based meetups. It's like a digital common room — students and communities can raise or join last-minute trips, rides, jam sessions, games, movie nights, or any group activity with open spots.

Fiore evolved into a graph-powered engine for discovery and connection, built with FastAPI, PostgreSQL + Apache AGE, and object storage using MinIO. It supports REST, GraphQL, and WebSocket APIs and offers personalized, real-time recommendations.

---

## 🚀 Features

- FastAPI backend with modular architecture
- REST, GraphQL, and WebSocket APIs
- Real-time event-based communication with WebSockets
- Graph-driven user, event, and community recommendations using Apache AGE
- PostgreSQL for structured data
- MinIO for image and file storage (S3-compatible)
- JWT and API key authentication
- Pytest-based testing suite
- Docker-ready deployment (`docker` branch)

---

## 🧠 App Concept

Imagine you're a student wanting to go for a late-night coffee run, but you're looking for company. Or you're heading for a trip and have 2 empty seats. Or you're starting a pick-up game on campus. Fiore lets you **raise events on-the-fly**, and others can discover and **join them instantly** based on shared interests and time windows.

Communities can form around frequent event types. Profiles grow with participation. The social graph evolves. And everything runs in real time.

---

## 🧱 Tech Stack

| Purpose        | Tech                       |
|----------------|----------------------------|
| Language       | Python 3.11                |
| Backend        | FastAPI                    |
| ORM            | SQLAlchemy                 |
| GraphQL        | Strawberry                 |
| Realtime       | WebSocket                  |
| Database       | PostgreSQL + Apache AGE    |
| Object Storage | MinIO                      |
| Auth           | JWT, API Keys              |
| Testing        | Pytest                     |

---

## 🌐 API Overview

📜 Swagger UI: [http://localhost:8000/docs](http://localhost:8000/docs)

---

## ⚙️ Environment Configuration

Create a `.env` file in the root directory with the following variables:

```env
DB_USER=fiore
DB_PASSWORD=strong_paa
DB_NAME=fiore
DB_HOST=localhost
DB_PORT=5432

JWT_SECRET=secret

MINIO_ENDPOINT=http://localhost:9000
MINIO_ACCESS_KEY=key
MINIO_SECRET_KEY=secret
MINIO_BUCKET=fiore
MINIO_USE_SSL=False

API_KEY=random

TEST_USER_PASSWORD=user1
TEST_IMAGE_PATH_ABS=/path/to/image
```

---

## 🧠 Setting Up Apache AGE on PostgreSQL

1. **Install PostgreSQL** (version 13+ recommended):

```bash
sudo apt install postgresql postgresql-contrib
```

2. **Install Apache AGE**:
Follow the official guide: https://github.com/apache/age

3. **Enable AGE in your database**:

```sql
CREATE EXTENSION age;
LOAD 'age';
SET search_path = ag_catalog, "$user", public;
```

4. **Create a graph** (you can name it `fiore_graph`):

```sql
SELECT create_graph('fiore_graph');
```

5. **Run the schema**:

```bash
psql -U fiore_user -d fiore -f schema.sql
```

---

## 🖼️ MinIO Image Storage Setup (via Go)

Image uploads are handled via MinIO, which is an S3-compatible object store.

Here’s a basic setup snippet using the Go SDK:

```go
package main

import (
  "context"
  "github.com/minio/minio-go/v7"
  "github.com/minio/minio-go/v7/pkg/credentials"
  "log"
)

func main() {
  endpoint := "localhost:9000"
  accessKeyID := "key"
  secretAccessKey := "secret"
  useSSL := false

  minioClient, err := minio.New(endpoint, &minio.Options{
    Creds:  credentials.NewStaticV4(accessKeyID, secretAccessKey, ""),
    Secure: useSSL,
  })
  if err != nil {
    log.Fatalln(err)
  }

  bucketName := "fiore"
  location := "us-east-1"

  err = minioClient.MakeBucket(context.Background(), bucketName, minio.MakeBucketOptions{Region: location})
  if err != nil {
    exists, errBucketExists := minioClient.BucketExists(context.Background(), bucketName)
    if errBucketExists == nil && exists {
      log.Printf("Bucket %s already exists\n", bucketName)
    } else {
      log.Fatalln(err)
    }
  } else {
    log.Printf("Successfully created bucket %s\n", bucketName)
  }
}
```

This bucket will store all user-uploaded media files like avatars and banners.

---

## 🐳 Docker Deployment

To spin up the complete stack including API, PostgreSQL, AGE, and MinIO:

```bash
git checkout origin/docker
docker-compose up -d --build
```

This command launches everything in a self-contained environment using the preconfigured Dockerfiles and Compose file.

---

## 🧪 Running Tests

```bash
pytest tests
```

---

## 📜 License

Fiore is open-source under the MIT License.
