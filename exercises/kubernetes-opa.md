---
layout: exercise
exercise: 125
title: "Exercise: Kubernetes OPA - Gatekeeper"
tools: openssh-client git
directories_to_sync: ssh-config 
---

## Steps

Let's try another defense on the first cluster takeover scenario: "OPA Gatekeeper" in place of the pod security policy admission controller. We can use OPA Gatekeeper to prevent any account from deploying a host volume-mounting pod.

1. Start up a fresh lxterminal by clicking the "sparrow" logo in the bottom-left corner of the screen, clicking run, typing `lxterminal` and hitting enter. 


2. Start your Kubernetes cluster - we will use this one for all Kubernetes exercises except for the Cloud Attacks, Peirates and Node Attacks:

    ```shell
    /sync/bin/suspend-all-vms.sh
    /sync/bin/start-bustakube.sh
    ```

2. SSH into the Kubernetes control-plane node:

    ```shell
    ssh -i /sync/bustakube-node-key root@bustakube-controlplane
    ```

3. If the Bustakube cluster isn't in the first scenario, put it into that scenario.

    ```shell
    kubectl get pod apache-status >/dev/null 2>/dev/null || \
      /usr/share/bustakube/Scenario1-OwnTheNodes/stage-scenario-1.sh 
    ```

4. Deactivate the Pod Security Policy admission controller:

    ```shell
    /usr/local/bin/toggle-psp-controller.sh deactivate
    ```

5. Install gatekeeper, using our local copy of the GitHub-hosted manifest file:

    ```shell
    kubectl apply -f /usr/share/bustakube/gatekeeper.yaml
    ```

6. Confirm that Gatekeeper is running:

    ```shell
    kubectl wait -n gatekeeper-system deployment --all --timeout=3m \
     --for=condition=Available gatekeeper-controller-manager
    ```

7. Now clone the OPA Gatekeeper Library, to get constraints:

	```shell
	git clone https://github.com/open-policy-agent/gatekeeper-library.git
	```

8. Change directory into the set of templates corresponding to the pod security policies:

	```shell
	cd gatekeeper-library/library/pod-security-policy
	```

9. Look at the set of OPA Gatekeeper templates that match existing PSP capability:

    ```shell
    ls
    ```

10. Change directory into the template for host-filesystem use, comparable to the `hostPath` pod security policy:

    ```shell
    cd host-filesystem/
    ```

11. Apply the template:

    ```shell
    kubectl apply -f template.yaml
    ```

12. Confirm that the template is loaded:

    ```shell
    kubectl wait crd --all --for=condition=Established \
       k8spsphostfilesystem.constraints.gatekeeper.sh
    ```

13. Now apply the pod security policy-equivalent `hostPath` restriction constraint:

    ```shell
    kubectl apply -f samples/psp-host-filesystem/constraint.yaml
    ```

14. Now, let's see that we can't stage a pod that mounts the host filesystem:

    ```shell
    scenario_dir="/usr/share/bustakube/Scenario1-OwnTheNodes"
    kubectl apply -f ${scenario_dir}/Attack/attack-pod.yaml
    ```

15. Observe the error message that says our attack pod was blocked. This means OPA Gatekeeper has blocked our attack.

16. Now uninstall OPA Gatekeeper:

    ```shell
    kubectl delete -f \
    https://raw.githubusercontent.com/open-policy-agent/gatekeeper/release-3.8/deploy/gatekeeper.yaml
    ```

