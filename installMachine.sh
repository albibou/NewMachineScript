#! /bin/bash

# Get OS information
if [ -f /etc/os-release ]; then
  # Source the os-release file
  . /etc/os-release
  OS=$ID
  VERSION=$VERSION_ID
else
  # Fallback to uname if os-release is unavailable
  OS=$(uname -s | tr '[:upper:]' '[:lower:]')
  VERSION=$(uname -r)
fi

case "$OS" in
ubuntu | debian)
  echo "Detected $OS. Using apt-get."
  PM="apt-get"
  ;;
fedora | centos | rhel | rocky | almalinux)
  echo "Detected $OS. Using dnf/yum."
  PM="dnf"
  ;;
*)
  echo "Unsupported OS: $OS"
  exit 1
  ;;
esac

# Adding user to sudo group
USERNAME=$(whoami)
su -c "bash -c 'echo \"$USERNAME ALL=(ALL) NOPASSWD:ALL\" >> /etc/sudoers'"

# Update packages
sudo $PM update

#Install packages
is_installed() {
  command -v "$1" >/dev/null 2>&1
}

packages=("vim" "curl" "git" "gcc" "zsh" "terminator" "vagrant" "fasttrack-archive-keyring" "virtualbox")

for package in "${packages[@]}"; do
  if is_installed $package; then
    echo "$package is already installed."
  else
    echo "Installing $package..."
    sudo $PM install $package -y
    if [ "$package" = "fasttrack-archive-keyring" ]; then
      LINE="deb https://fasttrack.debian.net/debian-fasttrack/ bullseye-fasttrack main contrib"
      SOURCES_FILE="/etc/apt/sources.list"
      if grep -Fxq "$LINE" "$SOURCES_FILE"; then
        echo "The line is already present in $SOURCES_FILE."
      else
        echo "Adding the line to $SOURCES_FILE..."
        echo "$LINE" | sudo tee -a "$SOURCES_FILE" >/dev/null
        echo "Line added successfully."
      fi
      echo "Updating package lists..."
      sudo apt-get update
    fi
    if [ "$package" = "virtualbox" ]; then
      sudo apt install curl wget gnupg2 lsb-release -y
      curl -fsSL https://www.virtualbox.org/download/oracle_vbox_2016.asc | sudo gpg --dearmor -o /etc/apt/trusted.gpg.d/vbox.gpg
      curl -fsSL https://www.virtualbox.org/download/oracle_vbox.asc | sudo gpg --dearmor -o /etc/apt/trusted.gpg.d/oracle_vbox.gpg
      echo "deb [arch=amd64] http://download.virtualbox.org/virtualbox/debian $(lsb_release -cs) contrib" | sudo tee /etc/apt/sources.list.d/virtualbox.list
      sudo apt update
      sudo apt install linux-headers-$(uname -r) dkms -y
      sudo apt install virtualbox-7.0 -y
    fi
  fi
done

#Install NeoVim/LazyVim

if is_installed nvim; then
  echo "nvim is already installed."
else
  echo "installing nvim..."
  sudo curl -LO https://github.com/neovim/neovim/releases/latest/download/nvim.appimage
  sudo chmod 777 nvim.appimage
  sudo mkdir -p /opt/nvim
  sudo mv nvim.appimage /opt/nvim/nvim
  LINE='export PATH="$PATH:/opt/nvim/"'
  ZSHRC_FILE="$HOME/.zshrc"
  if grep -Fxq "$LINE" "$ZSHRC_FILE"; then
    echo "The line is already present in $ZSHRC_FILE."
  else
    sudo echo "$LINE" >>"$ZSHRC_FILE"
    echo "Added the line to $ZSHRC_FILE."
  fi
  sudo git clone https://github.com/LazyVim/starter ~/.config/nvim
  sudo rm -rf ~/.config/nvim/.git
fi

#Create SSH key

if [ -f ~/.ssh/id_rsa.pub ]; then
  cat ~/.ssh/id_rsa.pub
else
  ssh-keygen
  cat ~/.ssh/id_rsa.pub
fi
