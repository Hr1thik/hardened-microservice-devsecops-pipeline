# Hardened Microservice & Automated DevSecOps Pipeline

[![DevSecOps CI/CD Security Pipeline](https://github.com/Hr1thik/hardened-microservice-devsecops-pipeline/actions/workflows/devsecops-pipeline.yml/badge.svg)](https://github.com/Hr1thik/hardened-microservice-devsecops-pipeline/actions/workflows/devsecops-pipeline.yml)
[![Quality Gate Status](https://sonarcloud.io/api/project_badges/measure?project=Hr1thik_hardened-microservice-devsecops-pipeline&metric=alert_status)](https://sonarcloud.io/summary/new_code?id=Hr1thik_hardened-microservice-devsecops-pipeline)
[![Security Rating](https://sonarcloud.io/api/project_badges/measure?project=Hr1thik_hardened-microservice-devsecops-pipeline&metric=security_rating)](https://sonarcloud.io/summary/new_code?id=Hr1thik_hardened-microservice-devsecops-pipeline)
[![Vulnerabilities](https://sonarcloud.io/api/project_badges/measure?project=Hr1thik_hardened-microservice-devsecops-pipeline&metric=vulnerabilities)](https://sonarcloud.io/summary/new_code?id=Hr1thik_hardened-microservice-devsecops-pipeline)
![Kubernetes](https://img.shields.io/badge/Kubernetes-v1.30+-326CE5?logo=kubernetes&logoColor=white)
![Docker](https://img.shields.io/badge/Docker-Multi--Stage-2496ED?logo=docker&logoColor=white)
![Kyverno](https://img.shields.io/badge/Admission%20Policy-Kyverno-00A98F)
![Trivy](https://img.shields.io/badge/Security%20Scanner-Trivy-00A4A6)

A production-hardened Node.js microservice integrated into an automated shift-left DevSecOps CI/CD workflow. The project enforces automated secret discovery, Static Application Security Testing (SAST), Software Composition Analysis (SCA), Infrastructure as Code (IaC) security auditing, minimal container attack surfaces, and Kubernetes admission control guardrails.

---

## Architecture & Shift-Left Pipeline Flow

```text
Code Push / Pull Request
  │
  ├── Stage 1: SAST & Secrets Scanning
  │    ├── TruffleHog (Detect active & historical secrets/API keys)
  │    └── Semgrep (Static analysis against OWASP Top 10)
  │
  └── Stage 2: Container & IaC Security Scan
       ├── Trivy IaC Scanner (Validates K8s manifests for KSV misconfigurations)
       ├── Multi-Stage Docker Build (Alpine baseline, non-root, stripped package managers)
       └── Trivy Image Scan (Fails build on unpatched HIGH / CRITICAL vulnerabilities)
```

---

## Security Hardening Controls Implemented

| Layer | Tool / Standard | Remediated Controls |
| :--- | :--- | :--- |
| **Secrets Management** | TruffleHog & SOPS | Blocks active and historical credential leaks in git tree; integrates SOPS encrypted payloads. |
| **Source Code (SAST)** | Semgrep & SonarCloud | • Scans application logic against OWASP Top 10 vulnerabilities.<br>• Enforces secure HTTP response headers via `helmet`.<br>• Suppresses technology disclosure via `app.disable('x-powered-by')`.<br>• Hardens dependency install via `--ignore-scripts` to mitigate malicious lifecycle hooks. |
| **Container Runtime** | Docker & Trivy | • Upgrades base Alpine packages to patch OpenSSL (`libcrypto3`/`libssl3`) CVEs.<br>• Purges global package managers (`npm`, `npx`, `yarn`, `corepack`) from the runner image to reduce attack surface.<br>• Enforces execution under unprivileged UID/GID (`10001`).<br>• Adds container `HEALTHCHECK` probe (`DS-0026`). |
| **IaC / K8s Manifests** | Trivy Config Scan | • **KSV-0014:** Configures `readOnlyRootFilesystem: true`.<br>• **KSV-0110:** Restricts deployment to non-default namespace (`devsecops-prod`).<br>• **KSV-0020 / KSV-0021:** Enforces `runAsUser` and `runAsGroup` > 10000.<br>• **KSV-0030 / KSV-0104:** Configures `seccompProfile: RuntimeDefault`.<br>• **KSV-0125:** Enforces fully qualified registry domains. |
| **Admission Control** | Kyverno CLI | Enforces cluster admission policies requiring non-root workloads and blocking untagged or `:latest` images. |

---

## Repository Structure

```text
├── .github/
│   └── workflows/
│       └── devsecops-pipeline.yml   # Multi-stage security pipeline
├── k8s/
│   ├── deployment.yml               # Hardened Kubernetes workload
│   └── policies/
│       └── policy-disallow-root.yml # Kyverno admission control rules
├── secrets/
│   └── db-credential.enc.yml        # Sample SOPS-encrypted credentials
├── .dockerignore
├── .gitignore
├── Dockerfile                       # Hardened multi-stage build definition
├── package.json                     # Production dependencies (Express, Helmet)
├── package-lock.json
├── README.md
└── server.js                        # Microservice entrypoint with security headers
```

---

## Local Reproduction & Testing

You can run every scanner locally using Docker without installing additional runtime dependencies:

### 1. Build Container Image
```bash
docker build -t devsecops-app:v1.0.0 .
```

### 2. Trivy Configuration Scan (IaC)
```bash
docker run --rm -v ${PWD}:/src aquasec/trivy:latest config /src
```

### 3. Trivy Container Vulnerability Scan
```bash
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
  aquasec/trivy:latest image --severity HIGH,CRITICAL devsecops-app:v1.0.0
```

### 4. SAST Analysis (Semgrep)
```bash
docker run --rm -v ${PWD}:/src semgrep/semgrep semgrep scan --config auto
```

### 5. Admission Policy Validation (Kyverno CLI)
```bash
docker run --rm -v ${PWD}:/workspace ghcr.io/kyverno/kyverno-cli:latest \
  apply /workspace/k8s/policies/policy-disallow-root.yml \
  --resource /workspace/k8s/deployment.yml
```

---

## Service Endpoints

| Method | Route | Description |
| :--- | :--- | :--- |
| `GET` | `/` | Root service banner |
| `GET` | `/health` | Application status probe (used by K8s liveness & container healthcheck) |