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
  nodejs \
  npm

npm i -g @anthropic-ai/claude-code

snap install nvim --classic

curl -LsSf https://astral.sh/uv/install.sh | sh

add-apt-repository ppa:zhangsongcui3371/fastfetch
add-apt-repository ppa:maveonair/helix-editor
apt update
apt install fastfetch helix
