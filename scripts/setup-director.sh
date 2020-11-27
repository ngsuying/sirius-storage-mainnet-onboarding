#!/bin/sh
set -e

command_exists() {
        command -v "$@" > /dev/null 2>&1
}

user="$(id -un 2>/dev/null || true)"

sh_c='sh -c'
if [ "$user" != 'root' ]; then
	if command_exists sudo; then
		sh_c='sudo -E sh -c'
		elif command_exists su; then
		sh_c='su -c'
	else
		cat >&2 <<-'EOF'
		Error: this installer needs the ability to run commands as root.
		We are unable to find either "sudo" or "su" available to make this happen.
		EOF
		exit 1
	fi
fi

cmd='dfms-client'

git_raw_url='raw.githubusercontent.com/proximax-storage/sirius-storage-mainnet-onboarding'

git_branch='main'

ks_dir="$(eval echo ~$user)/.$cmd/keystore"

util_path="/tmp/pk2ks-util"

if [ -f "$ks_dir/main" ]; then
	echo "Error: there is an existing keystore file found in $ks_dir/main"
	exit 1
fi

echo "Download pk2ks utility"
curl -fsSL https://$git_raw_url/$git_branch/tools/pk2ks-util -o $util_path
chmod +x $util_path

echo "Store private key into keystore"
read -p "Enter Private Key: " priv_key

mkdir -p $ks_dir
$util_path -dir $ks_dir -key $priv_key

echo "Download $cmd binary file"
$sh_c "curl -fsSL https://sirius-storage-dfms.s3-ap-southeast-1.amazonaws.com/latest/$cmd -o /usr/local/bin/$cmd"
$sh_c "chmod +x /usr/local/bin/$cmd"

echo "Setting up systemd"
$sh_c "curl -fsSL https://$git_raw_url/$git_branch/systemd/$cmd.service -o /lib/systemd/system/$cmd.service"

$sh_c "sed -i "s/USERNAME/$user/g" /lib/systemd/system/$cmd.service"

$sh_c "systemctl daemon-reload"

echo "Starting $cmd"
$sh_c "systemctl start $cmd.service"

echo "Done"