# Production-Grade Docker Image for Next.js (with Prisma)

A highly flexible, secure, and production-ready Docker base image for Next.js applications, with first-class support for Prisma.

[![GitHub license](https://img.shields.io/badge/license-MIT-blue.svg?style=flat-square)](https://github.com/gecut/nextjs/blob/main/LICENSE)
[![Docker Pulls](https://img.shields.io/docker/pulls/gecut/nextjs.svg?style=flat-square)](https://hub.docker.com/r/gecut/nextjs)
[![GitHub stars](https://img.shields.io/github/stars/gecut/nextjs.svg?style=flat-square)](https://github.com/gecut/nextjs/stargazers)
[![GitHub issues](https://img.shields.io/github/issues/gecut/nextjs.svg?style=flat-square)](https://github.com/gecut/nextjs/issues)

**Docker Hub Image:** `ghcr.io/gecut/nextjs/with-prisma:<tag>`

---

## Table of Contents

- [Key Features](#key-features)
- [Prerequisites](#prerequisites)
- [How to Use in Your Project](#how-to-use-in-your-project)
  - [1. Create a `Dockerfile`](#1-create-a-dockerfile)
  - [2. Build Your Image](#2-build-your-image)
  - [3. Run the Container](#3-run-the-container)
- [Configuration](#configuration)
- [Architectural Philosophy](#architectural-philosophy)
- [Development Guide](#development-guide)
  - [File Structure](#file-structure)
  - [How to Add a New Startup Task](#how-to-add-a-new-startup-task)
- [Roadmap](#roadmap)
- [Contributing](#contributing)
- [Frequently Asked Questions (FAQ)](#frequently-asked-questions-faq)
- [License](#license)
- [Author](#author)

---

## Key Features

- **🔒 Security First:** Runs the application as a non-root user (`nextjs`) to minimize security risks.
- **🧩 Modular & Extensible:** Uses a script-based startup system. Simply add or remove shell scripts in the `/scripts` directory to customize the startup sequence.
- **⚡ Optimized for Production:** Built with multi-stage builds to create a small and efficient final image.
- **🛠️ Flexible Package Manager:** Supports `pnpm`, `yarn`, and `npm` out of the box.
- **🔄 Built-in Revalidation:** Includes a mechanism to automatically revalidate Next.js pages on startup.
- **🗃️ Prisma Ready:** Automatically runs database migrations (`prisma migrate deploy`) during the startup sequence.

## Prerequisites

To use this Docker image, you will need the following tools installed on your local machine:
- [Docker](https://www.docker.com/get-started)
- [Docker Compose](https://docs.docker.com/compose/install/) (recommended for local development)

## How to Use in Your Project

Integrating this base image into your Next.js project is straightforward.

### 1. Create a `Dockerfile`

Create a `Dockerfile` in the root of your Next.js project with the following content. The base image handles all the heavy lifting.

```docker
# Use the desired version tag. Using 'latest' is convenient but pinning to a specific version is safer for production.
FROM ghcr.io/gecut/nextjs/with-prisma:latest

# Copy your application code into the image.
# The base image knows where to put it.
COPY . .
```

### 2. Build Your Image

Open your terminal and run the build command:

```bash
docker build -t my-awesome-next-app .
```

**To use a different package manager (default is `pnpm`):**

```bash
# For Yarn
docker build --build-arg PACKAGE_MANAGER=yarn -t my-awesome-next-app .

# For NPM
docker build --build-arg PACKAGE_MANAGER=npm -t my-awesome-next-app .
```

### 3. Run the Container

The easiest way to run the container is with `docker-compose`.

Create a `docker-compose.yml` file:
```yaml
version: '3.8'

services:
  app:
    # Use the image you just built
    image: my-awesome-next-app
    build: .
    ports:
      - "3000:3000"
    environment:
      # See the Configuration section for all available variables
      - PORT=3000
      - REVALIDATE_SECRET=YOUR_SUPER_SECRET_TOKEN
      - UPLOADS_STORAGE_PATH=/app/public/uploads
    volumes:
      # Persist uploaded files by mounting a volume
      - ./public/uploads:/app/public/uploads
```

Then, start your application:
```bash
docker-compose up
```

## Configuration

The behavior of the startup scripts can be controlled via these environment variables:

| Variable | Description | Default |
| :--- | :--- | :--- |
| `PORT` | The port the Next.js server will listen on. | `3000` |
| `REVALIDATE_SECRET` | A secret token used to secure the `/api/revalidate` endpoint. If not set, revalidation is skipped. | (none) |
| `*_STORAGE_PATH` | Any variable ending with this suffix will be treated as a path whose permissions need to be fixed for the `nextjs` user. | (none) |
| `ORIGIN` | The base URL for the revalidation request (e.g., your production domain). | `http://localhost:3000`|

## Architectural Philosophy

1.  **Orchestrator Pattern (`setup.sh`)**: The main `setup.sh` script acts as an orchestrator that simply executes every `*.sh` file within the `/scripts` directory in numerical/alphabetical order.
2.  **Modular Startup (`/scripts` directory)**: Every distinct startup task (fixing permissions, running migrations) is isolated in its own script for clarity, extensibility, and maintainability.
3.  **Security through Privilege Separation**: The container starts as `root` to perform setup tasks, but the final script (`99-entrypoint.sh`) uses `su-exec` to drop privileges and execute the application as the unprivileged `nextjs` user.

## Development Guide

This section is for those who want to contribute to or modify this base image project itself.

### File Structure

```
.
├── Dockerfile          # The core Docker multi-stage build instructions.
├── setup.sh            # The root orchestrator script (the main ENTRYPOINT).
└── scripts/
    ├── 10-fix-permission.sh  # Fixes storage path permissions.
    ├── 20-prisma-migrate.sh  # Runs Prisma migrations.
    ├── 30-revalidate.sh      # Triggers Next.js revalidation in the background.
    └── 99-entrypoint.sh      # The final script that starts the Node.js process.
```

### How to Add a New Startup Task

1.  Create a new shell script in the `scripts/` directory.
2.  Name it with a number reflecting its execution order (e.g., `25-my-task.sh`).
3.  Write your task logic. If you need to run a command as the `nextjs` user, use `su-exec nextjs <your-command>`.
4.  Make the script executable (`chmod +x`). The orchestrator will automatically pick it up.

## Roadmap

- [ ] Implement a `HEALTHCHECK` instruction in the Dockerfile.
- [ ] Add support for graceful shutdowns within the application process.
- [ ] Create more script examples for common use-cases.

## Contributing

Contributions are welcome! If you have suggestions or find a bug, please feel free to:
1.  [Fork the repository](https://github.com/gecut/nextjs/fork)
2.  Create your feature branch (`git checkout -b feature/AmazingFeature`)
3.  Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4.  Push to the branch (`git push origin feature/AmazingFeature`)
5.  Open a Pull Request

For bugs and support, please [open an issue](https://github.com/gecut/nextjs/issues/new).

## Frequently Asked Questions (FAQ)

**Q: Why does the revalidation script wait for 5 seconds?**
**A:** This delay gives the Next.js server enough time to fully start up and be ready to accept HTTP requests. Without it, the `curl` command might fail because it tries to connect to a server that isn't running yet.

**Q: Can I run custom commands before the application starts?**
**A:** Yes! That's the primary benefit of this architecture. Simply create a new script in the `scripts/` directory with the desired execution number, and it will run automatically.

## License

This project is licensed under the MIT License. See the `LICENSE` file for details.

## Author

- **gecut** - [GitHub Profile](https://github.com/gecut)
