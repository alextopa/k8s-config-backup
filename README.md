# k8s-config-backup
A script that downloads the current state of all k8s components to YAML files.

This script is mainly the same as the one in this [repository](https://github.com/pieterlange/kube-backup).
The main difference is that this script just downloads them locally and does not put them in a repository.
There might be other smaller changes, but I do not remember them.

## Prerequisites

kubectl installed and available by the $PATH environment variable

## Usage

Just run the script:

```bash
chmod +x k8_backup.sh
./k8s_backup.sh
```