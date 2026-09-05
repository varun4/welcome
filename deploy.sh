#!/bin/bash
set -e

REPO="varun4/welcome"
cd "$(dirname "$0")"

# Self-update: pull latest, re-exec if script changed
OLD_HASH=$(git rev-parse HEAD 2>/dev/null || echo "")
git fetch origin main 2>/dev/null && git reset --hard origin/main 2>/dev/null || git pull origin main 2>/dev/null || true
NEW_HASH=$(git rev-parse HEAD 2>/dev/null || echo "")
if [ "$OLD_HASH" != "$NEW_HASH" ]; then
  echo "Script updated. Re-executing..."
  exec "$0" "$@"
fi

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
  echo "Unsupported package manager. Install manually: git, docker, gh"
  exit 1
fi

# Install each dependency from dependencies.txt
while IFS= read -r dep; do
  [ -z "$dep" ] && continue
  if command -v "$dep" &>/dev/null; then
    echo "  $dep ✓"
    continue
  fi
  echo "Installing $dep..."
  case "$dep" in
    git)
      $PKG_UPDATE && $PKG_INSTALL git
      ;;
    docker)
      curl -fsSL https://get.docker.com | sudo sh
      ;;
    gh)
      if command -v apt-get &>/dev/null; then
        curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg 2>/dev/null
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
        $PKG_UPDATE && $PKG_INSTALL gh
      elif command -v brew &>/dev/null; then
        brew install gh
      fi
      ;;
    *)
      $PKG_UPDATE && $PKG_INSTALL "$dep" 2>/dev/null || echo "  Warning: could not install $dep"
      ;;
  esac
done < dependencies.txt

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

# Clone if not yet a repo
if [ ! -d .git ]; then
  echo "Cloning repo..."
  gh repo clone "$REPO" .
fi

# Ensure privileged ports are available for rootless Docker
if [ "$(sysctl -n net.ipv4.ip_unprivileged_port_start 2>/dev/null)" != "80" ]; then
  echo "Setting net.ipv4.ip_unprivileged_port_start=80..."
  echo "net.ipv4.ip_unprivileged_port_start=80" | sudo tee -a /etc/sysctl.conf > /dev/null
  sudo sysctl -p
fi

echo "Rebuilding and restarting containers..."
docker compose down
docker compose up -d --build

echo "Done. Serving at http://localhost"
