---
layout: exercise
exercise: -5
title: "Exercise: Exercise Updates, Laptop Troubleshooting..."
---


## Virtual machines 

In any exercise involving the Kubernetes clusters, we're occasionally having node virtual machines shutdown. Check to see if all three nodes are up and/or start them back up in virt-manager

  ```shell
  virt-manager
  ```


## If you're missing the /root/bhusa2023 directory

1. Clone the repo [bhusa2023](https://github.com/bustakube/bhusa2023) into the `/root` directory. 
    - You will need a Github Account. [Github Signup](https://github.com/signup?ref_cta=Sign+up&ref_loc=header+logged+out&ref_page=%2F&source=header-home)
    - Creata a new [Github Token](https://github.com/settings/tokens). 
      - Generate new token (classic)
        - Note: `bh2023-class`
        - Expiration: `7 days`
        - Enable `write:packages` and `read:packages`
        - **SAVE** your token!!!
    - We need to add your Github user to the project repository.
      - Give the proctors your username
    - Check your Github notifications
      - Accept the access invitation to `bustakube/bhusa2023`
1. We expect your repository clone to be cloned into `/root/bhusa2023`. 
    ```shell
    cd /root
    git clone https://github.com/bustakube/bhusa2023.git
    ```
1. Run the follwing script to save your token to the `/root/.gitconfig`
    ```shell
    /root/bhusa2023/bin/github-login.sh
    ```


## Updating your exercises, scripts, and slides

To get the lastest updates: exercises, slides and scripts.

```shell
/root/bhusa2023/bin/sync-exercises.sh
```

## Exercise Troubleshooting/Fix Scripts

You may or may not need to run these scripts. 

### Cloud Attacks, Node Attacks, Peirates

Please run this script:

```shell
/root/bhusa2023/bin/get-cloud-clusters.sh
```

### Kubernetes Own the Nodes

You'll need to replace the virtual machine configurations for the three Bustakube nodes.

```shell
/root/bhusa2023/bin/kubernetes-own-the-nodes.sh
```

### bustakube-control-plane crashing?

Please close your browser tabs. Memory is tight on these laptops. Run the following to create a swapfile to increase your memory. You should only run this script once. Each run will create  6G `/swapfile-XXXXXXX` and add it to your `/etc/fstab`

```shell
/root/bhusa2023/bin/increase-swap.sh
```

### Download Peirates

```shell
github="https://github.com/inguardians/peirates"
wget ${github}/releases/download/v1.1.12/peirates-linux-amd64.tar.xz
```

### OPA Gatekeeper exercise

You can get a modified version of the gatekeeper.yaml manifest file by running this:

```shell
/root/bhusa2023/bin/add-gatekeeper-manifest-to-bustakube.sh
```
### After Gatekeeper Exercise:

Please uninstall Gatekeeper:

```shell
kubectl delete -f \
https://raw.githubusercontent.com/open-policy-agent/gatekeeper/release-3.8/deploy/gatekeeper.yaml
```