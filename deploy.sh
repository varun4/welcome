#!/bin/bash
set -e

cd "$(dirname "$0")"

echo "Checking dependencies..."

# Detect package manager
if command -v apt-get &>/dev/null; then
  PKG_UPDATE="sudo apt-get update -qq"
  PKG_INSTALL="sudo apt-get install -y -qq"
elif command -v yum &>/dev/null; then
  PKG_UPDATE="sudo yum makecache -q"
  PKG_INSTALL="sudo yum install -y -q"
elif command -v brew &>/dev/null; then
  PKG_UPDATE="brew update"
  PKG_INSTALL="brew install"
else
  echo "Unsupported package manager. Install manually: git, docker, docker compose"
  exit 1
fi

# git
if ! command -v git &>/dev/null; then
  echo "Installing git..."
  $PKG_UPDATE && $PKG_INSTALL git
fi

# docker
if ! command -v docker &>/dev/null; then
  echo "Installing docker..."
  curl -fsSL https://get.docker.com | sudo sh
fi

# docker compose plugin
if ! docker compose version &>/dev/null; then
  echo "Installing docker compose plugin..."
  $PKG_INSTALL docker-compose-plugin 2>/dev/null || {
    COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep tag_name | cut -d '"' -f 4)
    sudo curl -L "https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" \
      -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
  }
fi

# Add user to docker group
if ! groups "$USER" | grep -q docker; then
  sudo usermod -aG docker "$USER" 2>/dev/null || true
  echo "Added to docker group. Log out and back in for it to take effect."
fi

echo "All dependencies installed."

echo "Pulling latest changes..."
git pull origin main

echo "Rebuilding and restarting containers..."
docker compose down
docker compose up -d --build

echo "Done. Serving at http://localhost"
