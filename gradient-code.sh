cd /notebooks

curl -Lk 'https://code.visualstudio.com/sha/download?build=stable&os=cli-alpine-x64' --output vscode_cli.tar.gz
tar -xf vscode_cli.tar.gz

mkdir -p /storage/.vscode/server
ln -s /storage/.vscode/server $HOME/.vscode-server
cp code /storage/.vscode/code

/storage/.vscode/code tunnel --accept-server-license-terms --name=gradient-tyrannulet
