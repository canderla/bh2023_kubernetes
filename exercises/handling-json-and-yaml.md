---
layout: exercise
exercise: 28
title: "Exercise: Handling JSON and YAML"
---

1. Start up a fresh lxterminal by clicking the "sparrow" logo in the bottom-left corner of the screen, clicking run, typing `lxterminal` and hitting enter. Alternatively, use the hot key sequence below:

	```
	<hold down Alt><hit F2>lxterminal<HIT the enter key>
	```

2. SSH into the control plane node on the cluster:

    ```shell
    ssh -i /sync/bustakube-node-key root@bustakube-controlplane
    ```


3. In this exercise, we'll use configMaps, secrets, namespaces, and pods to get comfortable with JSON and YAML.
First, let's create a pod with a an ordinary volume. We define volumes in the pod manifest file. There isn't a kubectl run argument for this, so let's create a sample manifest with kubectl's `--dry-run=client -o yaml` argument:

    ```shell
    image="docker-registry:5000/nginx"
    kubectl run pod-with-vol --image=$image --dry-run=client -o yaml
    ```

4. Let's use the same command, but use json output, so we can use jq to add a "volumes" section to the "spec" section, at the same level of indention as the "containers" section:

    ```shell
    kubectl run pod-with-vol --image=$image --dry-run=client -o json \
     | jq '.spec.volumes[0].name="myvolume"'
    ```

5. Take a look at how that created a volumes section, with a first item that had the name "myvolume".  Here's the output on our test system, though we've removed a few lines for ease to make it easier to follow:

    ```
    {
    "kind": "Pod",
    "apiVersion": "v1",
    "metadata": {
        "name": "pod-with-vol",
    },
    "spec": {
        "containers": [
        {
            "name": "pod-with-vol",
            "image": "docker-registry:5000/nginx",
            "resources": {}
        }
        ],
        "volumes": [
        {
            "name": "myvolume"
        }
        ]
    },
    }
    ```

6. Add one more assignment to the jq expression, so we give this volume a type of EmptyDir:

    ```shell
    kubectl run pod-with-vol --image=$image --dry-run=client -o json | jq \
      '.spec.volumes[0].name="myvolume" | .spec.volumes[0].emptyDir={}'
    ```

7. jq is wonderful, but it works exclusively with JSON. YAML is easier to read than JSON. Let's install yq, which is a jq wrapper that lets us handle both JSON and YAML:

    ```shell
    which yq >/dev/null 2>/dev/null
    if [ $? -ne 0 ]; then
       url="https://github.com/mikefarah/yq/releases/download/v4.23.1/yq_linux_amd64 "
       curl -o /usr/bin/yq $url
       chmod +x /usr/bin/yq
    fi
    ```

8. Let's repeat that manifest creation but without getting any JSON output. yq uses the same JSON-modification language, but can take YAML and input. It will output JSON, unless we add the `-Y` flag.

    ```shell
    kubectl run pod-with-vol --image=$image --dry-run=client -o yaml | \
      yq -Y '.spec.volumes[0].name="myvolume" | .spec.volumes[0].emptyDir={}'
    ```

9. Let's write this YAML manifest to a file:

    ```shell
    kubectl run pod-with-vol --image=$image --dry-run=client -o yaml | \
     yq -Y '.spec.volumes[0].name="myvolume" | .spec.volumes[0].emptyDir={}' \
     >pod-with-vol.yaml
    ```

10. Let's take at that file's volume-specific parts by using grep to see just the 7 lines before the "volumes" line and the 2 lines after it:

    ```shell
    cat pod-with-vol.yaml | grep -B 7 -A 2 volumes:
    ```

11. Notice how the volumes list was created. Here's the output of the last command on our test system:

    ```
    spec:
    containers:
    - image: docker-registry:5000/nginx
        name: pod-with-vol
        resources: {}
    dnsPolicy: ClusterFirst
    restartPolicy: Always
    volumes:
    - emptyDir: {}
        name: myvolume
    ```

12. Let's keep going. So far, you've added a volume to the pod, but for this to be useful, you need to mount the `myvolume` volume into a container. Use yq to see the first container item in the containers list, as it stands right now:

    ```
    cat pod-with-vol.yaml | yq -Y '.spec.containers[0]'
    ```

13. Notice that this container doesn't have any `volumeMounts` yet. Here's the output of the last command on our test system:

    ```
    image: docker-registry:5000/nginx
    name: pod-with-vol
    resources: {}
    ```

14. Add a `volumeMount` to the first container. The command below adds it and then shows you just the containers section of the JSON manifest:

    ```shell
    cat pod-with-vol.yaml | yq -Y '.spec.containers[0].volumeMounts[0].name="myvolume"' | grep -A 5 containers
    ```

15. Now add one more part to the yq expression, to add a `mountPath` to the first `volumeMount`: 

    ```shell
    cat pod-with-vol.yaml | yq  -Y \
      '.spec.containers[0].volumeMounts[0].name="myvolume" | .spec.containers[0].volumeMounts[0].mountPath="/mnt"' \
      >pod-with-vol-mounted.yaml
    ```

16. Take a look at the first 12 lines of the spec:

    ```shell
    cat pod-with-vol-mounted.yaml | grep -A 12 spec:
    ```

17. Notice how the spec section has a container that mounts the `myvolume` volume onto `/mnt` and a volume that defines an EmptyDir volume, naming it `myvolume`. Here's the output of the last command on our test system:

    ```
    spec:
      containers:
      - image: docker-registry:5000/nginx
        name: pod-with-vol
      resources: {}
      volumeMounts:
        - name: myvolume
          mountPath: /mnt
      dnsPolicy: ClusterFirst
      restartPolicy: Always
      volumes:
      - name: myvolume
        emptyDir: {}
    ```

18. Let's add the image pull secret to allow the use of the private registry:

    ```shell
    cat pod-with-vol-mounted.yaml | yq -Y \
      '.spec.imagePullSecrets[0].name="regcred-docker-registry-5000"' \
      >pod-with-vol-mounted-regcred.yaml
    ```

18. Temporary for BHUSA2023: if you had created the pod already and so the new version isn't accepted, please delete the old pod:

    ```
    kubectl delete pod pod-with-vol
    ```

18. Let's create that pod, straight from the YAML manifest:

    ```shell
    kubectl apply -f pod-with-vol-mounted-regcred.yaml
    ```

19. Run a command in the pod's main container to see how Kubernetes mounts something onto the container's /mnt. We'll do it non-interactively:

    ```shell
    kubectl exec pod-with-vol -- /bin/sh -c 'mount | grep mnt'
    ```

20. Notice that the volume seems to be mounted from a device file, from the perspective of the container. Here's the output of the last command on our test system:

    ```
    /dev/vda3 on /mnt type ext4 (rw,relatime,errors=remount-ro)
    ```

21. That's enough about volumes for now. Let's get to ConfigMaps. ConfigMaps let us create an object with data (often configuration) that we'd like to pass into one or more pods. This data is written as key-value pairs. Let's create a simple configmap called cm-prod-db that contains two keys, dbname and ip, and their respective values, prod and 1.2.3.4:

    ```shell
    kubectl create configmap cm-prod-db --from-literal=dbname=prod --from-literal=ip=1.2.3.4
    ```

22. Take a look at the object this created - in the `data:` section, it shows the key-value pairs we set:

    ```shell
    kubectl get configmap cm-prod-db -o yaml
    ```

23. This is one of the few places where ```get <resource> -o yaml``` is more readable than ```describe resource```.  See for yourself:

    ```shell
    kubectl describe configmap cm-prod-db
    ```

24. `configmap` is a long word to keep typing - look up its short form with ```kubectl api-resources```:

    ```shell
    kubectl api-resources | grep configmaps
    ```

25. Let's get a list of configmaps:

    ```shell
    kubectl get cm
    ```

26. Now, let's create a pod manifest that defines an environment variable from this ConfigMap:

    ```shell
    cat <<EOF >env-uses-cmap.yaml
    kind: Pod
    apiVersion: v1
    metadata:
      name:      env-uses-cmap
    spec:
      containers:
      - name:    myctr
        image:   docker-registry:5000/nginx
        env:
        - name: DBIP
          valueFrom:
            configMapKeyRef:
              name: cm-prod-db
              key: ip
      imagePullSecrets:
      - name: regcred-docker-registry-5000
    EOF
    ```

27. Create a pod from this manifest:

    ```shell
    kubectl create -f env-uses-cmap.yaml
    ```

28. Use `kubectl exec` to see the environment variable:

    ```shell
    kubectl exec env-uses-cmap -- env
    ```

29. Notice that the `DBIP` environment variable is set to the ConfigMap's value for `ip`. Here's the output of the last command on our test system: 

    ```
    PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
    HOSTNAME=env-uses-cmap
    DBIP=1.2.3.4
    KUBERNETES_PORT=tcp://10.96.0.1:443
    KUBERNETES_PORT_443_TCP=tcp://10.96.0.1:443
    KUBERNETES_PORT_443_TCP_PROTO=tcp
    KUBERNETES_PORT_443_TCP_PORT=443
    KUBERNETES_PORT_443_TCP_ADDR=10.96.0.1
    KUBERNETES_SERVICE_HOST=10.96.0.1
    KUBERNETES_SERVICE_PORT=443
    KUBERNETES_SERVICE_PORT_HTTPS=443
    NGINX_VERSION=1.21.6
    NJS_VERSION=0.7.2
    PKG_RELEASE=1~bullseye
    HOME=/root
    ```

30. The values in a configmap can even be full files. Let's create a ConfigMap from a directory of files. First, create an html directory:

    ```shell
    mkdir html
    ```

31. Next, create a file called 50x.html in that directory:

    ```shell
    echo "500-style error!" >html/50x.html
    ```

32. Create one more file in the directory, an index.html file:

    ```shell
    cat <<EOF >html/index.html
    <html>
    <head>
    <title>Welcome to nginx!</title>
    </head>
    </html>
    EOF
    ```

33. Now create a ConfigMap called `cm-nginx` from that directory:

    ```shell
    kubectl create configmap cm-nginx --from-file=html/
    ```

34. Take a look at the ConfigMap:

    ```shell
    kubectl get cm cm-nginx -o yaml | egrep -A 9 '^data:'
    ```

35. Notice that the two text files you created in `html/` are embedded in the ConfigMap, with each filename being a key in the data section. Here's the output on our test system:

    ```
    data:
      50x.html: |
        500-style error!
      index.html: |
        <html>
        <head>
        <title>Welcome to nginx!</title>
        </head>
        </html>
    kind: ConfigMap
    ```

36. Finally, create a pod manifest that uses `cm-nginx` as a configMap-type volume and mounts it into the container's /etc/nginx/conf.d/ directory:

    ```shell
    cat <<EOF >nginx-cm-vol.yaml
    kind: Pod
    apiVersion: v1
    metadata:
      name:       nginx-cm-vol
    spec:
      containers:
      - name:     nginx-cm-vol
        image:    docker-registry:5000/nginx
        volumeMounts:
        - name:    configfiles
          mountPath: "/etc/nginx/conf.d/"
          readOnly: true
      volumes:
      - name:     configfiles
        configMap:
          name:   cm-nginx
      imagePullSecrets:
      - name: regcred-docker-registry-5000
    EOF
    ```

37. Create the pod:

    ```shell
    kubectl create -f nginx-cm-vol.yaml
    ```

38. Exec a find command in the pod to see how the ConfigMap's contents landed in the filesystem:

    ```shell
    kubectl exec nginx-cm-vol -- find /etc/nginx/conf.d/
    ```

39. Now, let's create a namespace that we can put resources into:

    ```shell
    kubectl create namespace space
    ```

40. Take a look at the manifest that command creates:

    ```shell
    kubectl create namespace space --dry-run=client -o yaml
    ```

41. Notice that it's a pretty simple object. Here's the output on our test system:

    ```
    apiVersion: v1
    kind: Namespace
    metadata:
      creationTimestamp: null
      name: space
    spec: {}
    status: {}
    ```

42. Let's find the short name for namespace:

    ```shell
    kubectl api-resources | grep namespaces
    ```

43. Let's list the available namespaces:

    ```shell
    kubectl get ns
    ```

44. Now let's create a secret in our new namespace. Create the manifest first, passing in `-n space` to say this command should refer to the `space` namespace, not the `default` namespace (which all of our previous commands did):

    ```shell
    kubectl -n space create secret generic db-creds \
      --from-literal=acctname=invservice \
      --from-literal=password=drowssap \
      --dry-run=client -o yaml
    ```

45. Notice how a secret's data section looks similar to a configmap's data section, except that the values are Base64-encoded. Also notice the `namespace:` item in the `metadata` section. Here's the output on our test system:

    ```
    apiVersion: v1
    data:
      acctname: aW52c2VydmljZQ==
      password: ZHJvd3NzYXA=
    kind: Secret
    metadata:
      creationTimestamp: null
      name: db-creds
      namespace: space
    ```

46. Save the manifest to a YAML file:

    ```shell
    kubectl create -n space secret generic db-creds --from-literal=acctname=invservice --from-literal=password=drowssap --dry-run=client -o yaml >secret-db-creds.yaml
    ```

47. Now decode the acctname key's value, using yq's `-r` flag to get the "raw" output, that is, the output without quotation marks. We'll add an echo statement to the end to create a newline.

    ```shell
    cat secret-db-creds.yaml | yq -r '.data.acctname' | base64 -d ; echo ""
    ```

48. Notice that the value was the same as what we used to create the secret.  Here's the output on our test system:

    ```
    invservice
    ```

49. Create the secret from the manifest. Note that the `kubectl create` command doesn't need the `-n` flag, since the manifest already specifies the namespace.

    ```shell
    kubectl create -f secret-db-creds.yaml
    ```

50. Let's list all of the secrets in this namespace:

    ```shell
    kubectl -n space get secrets
    ```

51. Notice that we see our secret, as well as a default service account token secret. We'll talk about service account tokens later. Here's the output on our test system: 

    ```
    NAME                  TYPE                                  DATA   AGE
    db-creds              Opaque                                2      3s
    default-token-lzw8x   kubernetes.io/service-account-token   3      23m
    ```

52. Let's request that secret's contents, parse out the value of its `password` entry, and Base64 decode it:

    ```shell
    kubectl -n space get secret db-creds -o yaml | yq -r '.data.password' | base64 -d ; echo ""
    ```

53. Notice that this is the same password we created the secret with. Here's the output on our test system:

    ```
    drowssap
    ```

54. This exercise is over.
