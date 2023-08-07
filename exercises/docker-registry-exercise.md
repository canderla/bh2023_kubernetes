---
layout: exercise
exercise: 15
title: "Exercise: Container Registry"
vm: docker
tools: openssh-client
directories_to_sync: ssh-config

---

## Steps

Docker has a very useful feature that uses this layered union-mounted filesystem.

When we build another container image whose `Dockerfile` has lines in common with a `Dockerfile` we've already built against, Docker keeps track of what filesystem layer contained the changes made by each step in the `Dockerfile`, and skips running the command when it knows what the results would be. We'll explore this here.

*NOTE: when an instruction shows you the results from our test system, it often won't match your machine exactly down to the numbers, especially when time units like seconds are involved.  Don't worry about this.*

1. Start up a fresh `lxterminal` by clicking the "sparrow" logo in the bottom-left corner of the screen, clicking run, typing `lxterminal` and hitting enter. Alternatively, use the hot key sequence below:

    ```
    <hold down Alt><hit F2>lxterminal<HIT the enter key>
    ```

2. Log in to the `docker` virtual machine with password `logidebtech`:

    ```shell
    ssh user@docker
    ```

3. Make sure you have the `gcr.io/distroless/base` image on this host - we have chosen it for its small filesystem size. `docker pull` retrieves the image from the `gcr.io` image registry and caches it on this machine's Docker cache. We've chosen a specific version of this container image from July 2023.

    ```shell
    repo="gcr.io/distroless/base@sha256:"
    tag="73deaaf6a207c1a33850257ba74e0f196bc418636cada9943a03d7abea980d6d"
    docker pull ${repo}${tag}
    ```

4. Start the Docker registry now on this host.

    ```shell
    docker run --name=registry -d  -p 5000:5000 \
    -e REGISTRY_STORAGE_FILESYSTEM_ROOTDIRECTORY=/data \
    -v /registrydata:/data --restart=always registry:2
    ```

5. Tag the `distroless/base` image you already have as `distroless-base`, but on your private local registry, where it will thus be named `localhost:5000/distroless-base`:

    ```shell
    
    docker tag ${repo}${tag} localhost:5000/distroless-base
    ```

6. Push this image up to your local registry:

    ```shell
    docker push localhost:5000/distroless-base
    ```

7. Now delete your local copy of `gcr.io/distroless/base`, but look at the free disk space before and after:

    ```shell
    df -m /
    docker rmi ${repo}${tag}
    df -m /
    ```

8. Notice that the operation didn't really free up space -- here's the output from our test system:

    ```
    Filesystem     1M-blocks  Used Available Use% Mounted on
    /dev/vda1           5883  2657      2950  48% /
    Untagged: gcr.io/distroless/base@sha256:73deaaf6a207c1a33850257ba74e0f196bc418636cada9943a03d7abea980d6d
    Filesystem     1M-blocks  Used Available Use% Mounted on
    /dev/vda1           5883  2657      2950  48% /
    ```

9. Now delete your local copy of your registry's `distroless-base` image using the `docker rmi` (remove image) command. Check the free disk space before and after:

    ```shell
    df -m /
    docker rmi localhost:5000/distroless-base
    df -m /
    ```

10. Notice that this image deletion did free up space and that this image remove command had three extra lines of output, saying that layers were deleted. Here's output from our test system:

    ```
    Filesystem     1M-blocks  Used Available Use% Mounted on
    /dev/vda1           5883  2657      2950  48% /

    Untagged: localhost:5000/distroless-base:latest
    Untagged: localhost:5000/distroless-base@sha256:c11cf17ee8a54dd3a44908ed3f38ffbfb41f1c8c6a2264de9b3e2f5ef4576006
    Deleted: sha256:e03afa0858f2679999f6f9403e47509b63c2905a42a638fb21089f639af4ab28
    Deleted: sha256:c4d1cfefb2a1af664d2b6836bd7dcdfd52c28a2c0ef1818e230c8aa5c1521a60
    Deleted: sha256:c455ff9a6648ab90925bc799231d85776c8c373c25aed889e73c302e40c0b786
    Deleted: sha256:44043657805a72c00d6f483e5e1c05211be291b47bd5edb2019f8b10206b271c
    Deleted: sha256:1ba79e3210ffec19b0aac78261ef3b56c9d572a84ce171d99f8c5e9f8c8ceec9
    Deleted: sha256:92c2f7f2279d20f21e80a81748d3e535ac005414c173369bad07900665f4ce38
    Deleted: sha256:7c9bca19ee3fad0b4f850527fb2f75115a075b6ef771b57f995c3322cb2bb64a
    Deleted: sha256:d1619da8540b89bfc797c583754f20f42e0846611104a59fa13701cdf5842255
    Deleted: sha256:0ffd82d96dd6ccfbbbb6bbc2492bd3d256b8cdb01144e8140a4c55f12ae835dc
    Deleted: sha256:18fdb66c6a41b89620c96035277ec03d4069d27ae0b174b0e89f26530eeba864
    Deleted: sha256:f96114e9454bb8b5edf548870b385293d170efffaaf27ec6bca0df5396b830ef
    Deleted: sha256:9300705518a3ff9222e78cbbabf1108e0b3336c28a1d40b05cfea89bc41d1bd0
    Deleted: sha256:e023e0e48e6e29e90e519f4dd356d058ff2bffbd16e28b802f3b8f93aa4ccb17

    Filesystem     1M-blocks  Used Available Use% Mounted on
    /dev/vda1           5883  2632      2975  47% /
    ```

11. Think about what's happening here. Docker is saving space by keeping a hash of each image layer and simply tagging one or more layers with whatever name we tag it with. So the `distroless/base` image layers aren't deleted until no tags refer to them.

12. Now, let's pull this image back down from our local registry:

    ```shell
    docker pull localhost:5000/distroless-base
    ```

13. Let's create an image based on this one. Switch directory to `/home/user/imagedev/`:

    ```shell
    cd /home/user/imagedev/
    ```

14. Create a `Dockerfile` in this directory.

    ```shell
    cat <<EOF >Dockerfile
    FROM localhost:5000/distroless-base
    COPY Dockerfile /usr/share
    EOF
    ```

15. This Dockerfile says we'll start with the `distroless/base` image you just pushed to the repository, then copies the current directory's Dockerfile into it.

    ```
    FROM localhost:5000/distroless-base
    COPY Dockerfile /usr/share
    ```

16. Build a container from this image with the `docker build` command, which takes a name (a tag) and a directory in which to find a `Dockerfile` file. We'll call this image `localhost:5000/base-plus-dockerfile`.

    ```shell
    docker build -t localhost:5000/base-plus-dockerfile .
    ```

17. Now let's build a more useful container image. Change directory to the ```build-with-du``` subdirectory:

    ```shell
    cd /home/user/imagedev/build-with-du
    ```

18. Display the `Dockerfile` in this directory.

    ```shell
    cat Dockerfile
    ```

19. Note how this Dockerfile starts with the `localhost:5000/distroless-base` image, then copies a `du` binary into `bin/`. It also uses two more directives, `ENTRYPOINT` and `CMD`, to specify a program to run when the container starts, along with any arguments passed in on the command line. Here's the sample output on our system:

    ```
    FROM localhost:5000/distroless-base
    COPY du bin/
    ENTRYPOINT ["/bin/du","-ks"]
    CMD ["/bin"]
    ```

20. Build a container from this image with the `docker build` command, which takes a tag and a directory in which to find a `Dockerfile` file.

    ```shell
    docker build -t localhost:5000/base-plus-du ./
    ```

21. Let's start a container based on `localhost:5000/base-plus-du`, using the `-d` (detach) flag to detach from the container's stdio. We'll name the container `ctr`:

    ```shell
    docker run -d --name=ctr localhost:5000/base-plus-du
    ```

22. This container has completed and exited, but we can go look at its output via the `docker logs` command:

    ```shell
    docker logs ctr
    ```

23. The output you see will be the size of the `/bin/` directory in bytes. Delete the container now:

    ```shell
    docker rm ctr
    ```

24. Note that the container's output gave us the disk usage of the `/bin` directory in kilobytes. What if we wanted this image to do the same thing, using `/bin` as a default directory to measure, but allowing the user to specify a different directory, say `/usr`, without having to rebuild the image? This is exactly what `CMD` does in the Dockerfile. It indicates arguments that you can override easily, by putting them on the end of the `docker run` command line. Let's remove the `-d` flag, so we can see the output in real time and add a `-rm` flag, so the container is destroyed as soon as it exits:

    ```shell
    docker run --rm --name=ctr2 localhost:5000/base-plus-du /usr
    ```

25. Note that we now see the total size of the `/usr` directory in kilobytes. So, you've seen how `ENTRYPOINT` and `CMD` interplay. Summarizing:

    - `ENTRYPOINT` tells Docker what program to run when this container starts. It can optionally include arguments. These arguments aren't easily overriden, unless the entire entrypoint program is replaced.

    - `CMD` indicates arguments that Docker should add to the command line created from `ENTRYPOINT`. These arguments are intended to be easily overwritten, the way we overwrote `/bin` with `/usr`.

    - This produces the situation where the command run as the container's first process will start with ```du -ks``` and end with either `/bin` or whatever is placed after the image name on the `docker run` command line.

26. Let's push this container image we've built to our local registry - the output should be interesting:

    ```shell
    docker push localhost:5000/base-plus-du
    ```

27. Note that the output shows that Docker didn't have to push the two of the layers to the registry, as the registry already had them! Our sample output follows:

    ```
    Using default tag: latest
    The push refers to repository [localhost:5000/base-plus-du]
    7d221ee8ae69: Pushed
    f89ce21aca6a: Mounted from distroless-base
    0b031aac6569: Mounted from distroless-base
    latest: digest: sha256:52ee4f9b7565d65f3c2db68afd97384ebadbe0899f0f6076ce2c5c43489550b6 size: 947
    ```

28. That will certainly make things faster, especially when we're pushing to an Internet-connected registry like Docker Hub! Let's delete the ```base-plus-du``` image from our local image cache - we'll leave it up on the registry, of course:

    ```shell
    docker rmi localhost:5000/base-plus-du
    ```

29. Now, let's pull down the container image again.

    ```shell
    docker pull localhost:5000/base-plus-du
    ```

30. Note that Docker didn't have to pull down some of the layers - the ones that were part of the `distroless-base` that it still had cached. Here's the sample output from our machine:

    ```
    Using default tag: latest
    latest: Pulling from base-plus-du
    36698cfa5275: Already exists
    6a8659ec8836: Already exists
    7cf3941d8a27: Already exists
    Digest: sha256:52ee4f9b7565d65f3c2db68afd97384ebadbe0899f0f6076ce2c5c43489550b6
    Status: Downloaded newer image for localhost:5000/base-plus-du:latest
    localhost:5000/base-plus-du:latest
    ```

31. Imagine that a colleague of yours had already cached `distroless-base` and wanted to download ```base-plus-du``` the way you just did. Their download time would be greatly reduced because they only need to pull down this one layer of the image: the layer that represents these lines from the `Dockerfile`:

    ```
    COPY du bin/
    ENTRYPOINT ["/bin/du","-ks"]
    CMD ["/bin"]
    ```

32. Let's run a container to see one more Docker feature: volume mounting. Start a new container based on ```base-plus-du```, but mount the host's `/usr` onto the container's `/mnt` directory using `-v`, and tell the container to do a disk usage tally of that directory:

    ```shell
    docker run -v /usr:/mnt --rm --name=ctr3 localhost:5000/base-plus-du \
     /mnt
    ```

33. Note that this operation took a little longer to run. It also showed the enormous size difference of your the virtual machine's `/usr` directory, versus that of the container's `/usr` directory. Here's the output of this command from our machine:

    ```
    1484456	/mnt
    ```

34. Finally, let's build the container image from the `/home/user/imagedev/busybox-from-scratch` directory, then explore it with an interactive shell. Here are the commands to build the image:

    ```shell
    cd /home/user/imagedev/busybox-from-scratch
    docker build -t localhost:5000/busyboxfromscratch .
    ```

35. Stop for a second to check how much smaller the last couple images you've built are than `centos` was:

    ```shell
    docker images | egrep '(centos|busybox|base-plus-du)'
    ```

36. Notice that the two images you built are about one tenth (0.1) times the size of the `centos:7` image.  Here's the sample output from our system:

    ```
    localhost:5000/busyboxfromscratch     latest    4cbcffbfe310   2 minutes ago    21.2MB
    localhost:5000/base-plus-du           latest    750eabf6a6b2   31 minutes ago   20.4MB
    centos                                7         eeb6ee3f44bd   6 months ago     204MB
    ```

37. Now explore the busybox image via an interactive shell in a running container - feel free to run a few commands in the container, but don't exit the shell:

    ```shell
    docker run -it --name=busybox \
    localhost:5000/busyboxfromscratch /bin/sh
    ```

38. Detach from the container's shell by holding down `Ctrl-P`, and then hitting `Q`.

39. Run a `docker inspect` command to see how you might get the details for a container, like its IP address:

    ```shell
    docker inspect busybox
    ```

40. Notice that the end of the output shows the container's IP address. After class, you can parse the rest of the output with `jq` if you'd like. You don't need to - just realize this is part of how Kubernetes will be orchestrating, say, networking, for thousands of containers. Here's the end of our sample output on that last command:

    ```
                        "IPAddress": "172.17.0.3",
                        "IPPrefixLen": 16,
                        "IPv6Gateway": "",
                        "GlobalIPv6Address": "",
                        "GlobalIPv6PrefixLen": 0,
                        "MacAddress": "02:42:ac:11:00:03",
                        "DriverOpts": null
                    }
                }
            }
        }
    ]
    ````

41. Feel free to close this terminal window/tab to disconnect your SSH session to this virtual machine.
