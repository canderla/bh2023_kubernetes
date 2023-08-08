---
layout: exercise
exercise: 115
title: "Exercise: Kubernetes CIS Benchmark and Kube-Bench"
tools: openssh-client unfinished
directories_to_sync: ssh-config CIS unfinished

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

4. Run `kube-bench`, passing the output into `more`:

    ```shell
    version="v0.6.17"
    docker run --pid=host -v /etc:/etc:ro -v /var:/var:ro \
    -v $(which kubectl):/usr/local/mount-from-host/bin/kubectl \
    -v ~/.kube:/.kube -e KUBECONFIG=/.kube/config \
    -t docker.io/aquasec/kube-bench:$version \
    run | more
    ```

5. Notice the structure of the output.  You have a section with `[PASS]`, `[FAIL]`, `[WARN]`, and `[INFO]` output for each item in the CIS Benchmark. Then you have "remediations" and "summary" sections for different components of the cluster.

6. Run `kube-bench` again, writing the output to a text file, named `benchoutput.txt`:

    ```shell
    docker run --pid=host -v /etc:/etc:ro -v /var:/var:ro \
    -v $(which kubectl):/usr/local/mount-from-host/bin/kubectl \
    -v ~/.kube:/.kube -e KUBECONFIG=/.kube/config \
    -t docker.io/aquasec/kube-bench:latest \
    run >benchoutput.txt
    ```

7. Let's take a look at just a specific item, item `1.2.20`, which discusses whether the API server program has profiling activated. First, we'll look at the `[FAIL]` line:

    ```shell
    grep '1.2.20 Ensure' benchoutput.txt
    ```

8. Notice that the line explains what test fails, along with an item number. Here's the output of the last command on our test system:

    ```
    [FAIL] 1.2.20 Ensure that the --profiling argument is set to false (Automated)
    ```

9. Next, let's look at the remediation lines that tell us how to pass the check:

    ```shell
    grep -A 3 '1.2.20 Edit' benchoutput.txt
    ```

10. Notice that the line explains that we need to add one parameter to the `kube-apiserver` pod's specification/manifest file. Here's the output of the last command on our test system:

    ```
    1.2.20 Edit the API server pod specification file /etc/kubernetes/manifests/kube-apiserver.yaml
    on the master node and set the below parameter.
    --profiling=false
    ```

11. Before we try to correct the issue, let's make sure this isn't a false positive by checking the `ps` output to make sure that `--profiling=false` does not appear on the `kube-apiserver` line. We're using `egrep` for regular expression-based `grep` and the `-o` flag to see only the part of the line that matches the pattern. We should get no output from this command.

    ```shell
    ps -ef | grep kube-apiserver | egrep -o 'profiling[^ ]+'
    ```

12. Notice that we got no output. This means that the `kube-apiserver` line in the `ps` output didn't have a `--profiling` parameter set. The default behavior for `kube-apiserver` is to have profiling active unless there's a `--profiling=false` parameter. Since there isn't one, profiling is active and this is not a false positive.

13. Let's update the `kube-apiserver` pod manifest file - it can be found in `/etc/kubernetes/manifests/kube-apiserver.yaml`. Back up the file first:

    ```shell
    cp /etc/kubernetes/manifests/kube-apiserver.yaml /root/
    ```

14. Let's use `yq` to add a line to this file. First, take a look at the `.spec` section of the file's first container:

    ```shell
    cat kube-apiserver.yaml | yq -Y '.spec.containers[0]' | head -32
    ```

15. We want to add `--profiling=false` to the list under `command:`. Let's see just this list:

    ```shell
    cat kube-apiserver.yaml | yq -Y '.spec.containers[0].command'
    ```

16. Let's add a single item to that list in the manifest. The first `yq` command below will add an item to the list located at `.spec.containers[0].command`. The second `yq` command will filter the output, so we see only that list, rather than the entire spec file:

    ```shell
    cat kube-apiserver.yaml | \
    yq '.spec.containers[0].command += ["--profiling=false"]' | \
    yq -Y '.spec.containers[0].command'
    ```

17. Notice that the last line of the output has this on it:

    ```shell
    - "--profiling=false"
    ```

18. Now that we've seen what will happen, let's create a new YAML file to replace the old one. We'll put our new YAML file on top of the original at `/etc/kubernetes/manifests/kube-apiserver.yaml`:

    ```shell
    cat kube-apiserver.yaml | \
    yq -Y '.spec.containers[0].command += ["--profiling=false"]' \
    >/etc/kubernetes/manifests/kube-apiserver.yaml
    ```

19. Now, let's restart the `kube-apiserver` pod's main container:

    ```shell
    cntr=$(docker ps | grep k8s_kube-apiserver | awk '{print $1}')
    docker rm -f $cntr
    ```

20. Make sure the API server has come back up - this command should return `1`:

    ```shell
    ps -ef | grep -c kube-apiserve[r]
    ```

21. Run `kube-bench` again, writing the output to a different file, named `benchoutput-post-profiling-change.txt`

    ```shell
    docker run --pid=host -v /etc:/etc:ro -v /var:/var:ro \
    -v $(which kubectl):/usr/local/mount-from-host/bin/kubectl \
    -v ~/.kube:/.kube -e KUBECONFIG=/.kube/config \
    -t docker.io/aquasec/kube-bench:latest \
    run >benchoutput-post-profiling-change.txt
    ```

22. Look at item `1.2.20`'s status in the `benchoutput-post-profiling-change.txt` file:

    ```shell
    grep '1.2.20 Ensure' benchoutput-post-profiling-change.txt
    ```

23. Good - we pass on that item now. Now, run a diff on the output:

    ```shell
    diff benchoutput.txt benchoutput-post-profiling-change.txt
    ```

24. Notice that, again, the output shows we're now passing that test and our number of PASS-ing checks increases by one. Here's the output on our test system - do not copy-and-paste this:

    ```
    44c44
    < [FAIL] 1.2.20 Ensure that the --profiling argument is set to false (Automated)
    ---
    > [PASS] 1.2.20 Ensure that the --profiling argument is set to false (Automated)
    119,122d118
    < 1.2.20 Edit the API server pod specification file /etc/kubernetes/manifests/kube-apiserver.yaml
    < on the master node and set the below parameter.
    < --profiling=false
    <
    176,177c172,173
    < 43 checks PASS
    < 10 checks FAIL
    ---
    > 44 checks PASS
    > 9 checks FAIL
    426,427c422,423
    < 68 checks PASS
    < 12 checks FAIL
    ---
    > 69 checks PASS
    > 11 checks FAIL
    ```

25. Take a look at the CIS Benchmark description for this item - you'll find a copy in `/sync/CIS/`
