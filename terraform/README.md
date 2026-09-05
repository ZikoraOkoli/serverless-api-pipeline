# Serverless API CI/CD Pipeline

An automated continuous integration and continuous deployment (CI/CD) pipeline for a containerized FastAPI application using Docker, Terraform, and GitHub Actions on AWS.

## Architecture & Features

* **FastAPI Application**: Lightweight Python REST API with automated unit testing via `pytest`.
* **Containerization**: Optimized Docker image based on `python:3.11-slim`.
* **Infrastructure as Code**: Terraform configurations to automatically provision an AWS Elastic Container Registry (ECR).
* **Automated CI/CD**: GitHub Actions workflow that automatically runs tests, builds the Docker image, authenticates with AWS, and pushes the container image to ECR upon every commit to `main`.

## Project Structure

```text
.
├── .github/
│   └── workflows/
│       └── deploy.yml    # GitHub Actions CI/CD workflow
├── app/
│   ├── main.py           # FastAPI application code
│   └── test_main.py      # Pytest test suite
├── terraform/
│   ├── main.tf           # AWS ECR infrastructure setup
│   └── variables.tf      # Infrastructure variables
├── Dockerfile            # Container build specification
├── requirements.txt      # Python dependencies
└── README.md