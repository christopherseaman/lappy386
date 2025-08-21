apt install \
  bat \
  build-essential \
  cmake \
  fastfetch \
  fd-find \
  findutils \
  fzf \
  git-delta \
  htop \
  ncdu \
  ripgrep \
  qemu-guest-agent \
  qemu-utils \
  spice-vdagent \
  software-properties-common

snap install nvim --classic

curl -LsSf https://astral.sh/uv/install.sh | sh

curl -sS https://starship.rs/install.sh | sh

curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.3/install.sh | bash
source ~/.bashrc
nvm install --lts
npm i -g @anthropic-ai/claude-code

sudo add-apt-repository ppa:jgmath2000/et
add-apt-repository ppa:zhangsongcui3371/fastfetch
add-apt-repository ppa:maveonair/helix-editor
apt update
apt install fastfetch helix et
