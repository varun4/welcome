#!/bin/bash
set -e

cd "$(dirname "$0")"

echo "Pulling latest changes..."
git pull origin main

echo "Rebuilding and restarting containers..."
docker compose down
docker compose up -d --build

echo "Done. Serving at http://localhost"
