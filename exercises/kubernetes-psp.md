---
layout: exercise
exercise: 50
title: "Exercise: Kubernetes Pod Security Policy Defense"
tools: openssh-client 
directories_to_sync: ssh-config 
---


## Steps


Let's try another defense on the cluster takeover scenario: pod security policies. Now we want to stop any non-admin account from staging the attack pod. Our other focus will be to make sure that any pod launched has to have an AppArmor profile.

1. Start up a fresh lxterminal by clicking the "sparrow" logo in the bottom-left corner of the screen, clicking run, typing `lxterminal` and hitting enter. Alternatively, use the hot key sequence below:

	```
	<hold down Alt><hit F2>lxterminal<HIT the enter key>
	```

2. Start your Kubernetes cluster - we will use this one for all Kubernetes exercises except for the Cloud Attacks, Peirates and Node Attacks:

   ```shell
   /sync/bin/suspend-all-vms.sh
   /sync/bin/start-bustakube.sh
   ```

3. Wait a minute for the VM to boot, then SSH into the control plane node on the cluster:

    ```shell
    ssh -i /sync/bustakube-node-key root@bustakube-controlplane
    ```

4. Run the stage script for the first scenario:

    ```shell
    cd /usr/share/bustakube/Scenario1-OwnTheNodes/
    ./stage-scenario-1.sh
    ```

5. Wait for the script to finish.

6. Let's remove the RBAC controls we had added at the end of the [Own the Nodes exercise](/exercises/kubernetes-own-the-nodes/).

    ```shell
    kubectl delete rolebinding get-only-on-pods-frontend-binding
    kubectl delete rolebinding get-only-on-pods-redis-binding
    cd Namespace-Default/
    kubectl apply -f binding-get-list-exec-pods-to-frontend.yaml
    kubectl apply -f binding-full-rw-and-exec-on-pods-to-redis.yaml
    ```

7. We'll apply a pod security policy (PSP) that will block any `hostPath` volumes from being mounted. Take a look:

    ```shell
    cd ../Defense/PodSecurityPolicies
    more psp-30-root-allowed-no-apparmor-required.yaml
    ```

8. Now, apply the pod security policy you just reviewed:

    ```shell
    kubectl apply -f psp-30-root-allowed-no-apparmor-required.yaml
    ```

9. We need a role, a list of actions that can be performed by any bound service accounts:

    ```shell
    kubectl apply -f \
     role-cluster-use-psp-30-root-allowed-no-apparmor-required.yaml
    ```

10. We'll need a binding that binds all authenticated users to this role:

    ```shell
    kubectl apply -f \
     binding-cluster-all-to-psp-30-root-allowed-no-apparmor-required.yaml
    ```

11. Before we go on, we'll need to activate the PodSecurityPolicy controller.

    ```shell
    /usr/local/bin/toggle-psp-controller.sh activate
    ```

12. Now, let's see that the `redis-master` pod's service account can't stage such a pod. First, copy `kubectl` and the attack pod definition into the `redis-master` pod:

    ```shell
    pod=`kubectl get pods | grep redis-master | awk '{print $1}'`
    kubectl cp /usr/bin/kubectl $pod:/usr/bin
    kubectl cp ../../Attack/attack-pod.yaml $pod:/tmp
    ```

13. Now, exec into the `redis-master` pod. to see whether it can stage a hostPath-mounting pod:

    ```shell
    kubectl exec -it $pod -- /bin/bash
    export PS1="\u@\h # "
    kubectl apply -f /tmp/attack-pod.yaml
    ```

14. For extra credit, see if you can modify the pod security policy to allow the `hostPath` pod mounting, but to force an AppArmor profile that won't permit the pod to read the host's `/etc/shadow` file.

    ```shell
    echo Extra credit - I am on my own here
    ```
