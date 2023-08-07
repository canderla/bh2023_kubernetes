---
layout: exercise
exercise: 3
title: "Exercise: Containers from Scratch"
tools: openssh-client 
directories_to_sync: ssh-config unfinished
vm: docker
---

## Steps

1. Start up a fresh `lxterminal` by clicking the "sparrow" logo in the bottom-left corner of the screen, clicking run, typing `lxterminal` and hitting enter. Alternatively, use the hot key sequence below:

    ```
    <hold down Alt><hit F2>lxterminal<HIT the enter key>
    ```

2. Log in to the docker virtual machine with password `logidebtech`:

    ```shell
    ssh user@docker
    ```

3. Sudo to `root` with the same password `logidebtech`:

    ```shell
    sudo su -
    ```

4. Just to make things easier to see, we're going to create a copy of bash called mysh.

    ```shell
    cp /bin/bash /bin/mysh
    ```

5. Let's get a list of the non-container-type namespaces on this system, using ```lsns``` (list namespaces):

    ```shell
    lsns | head -8
    ```

6. With output similar to the below, you should notice that the /sbin/init process has six (6) numbered namespaces, like so:

    ```
    NS         TYPE     NPROCS  PID  USER             COMMAND
    4026531834 time      96      1   root             /sbin/init
    4026531835 cgroup    96      1   root             /sbin/init
    4026531836 pid       96      1   root             /sbin/init
    4026531837 user      96      1   root             /sbin/init
    4026531838 uts       96      1   root             /sbin/init
    4026531839 ipc       96      1   root             /sbin/init
    4026531840 mnt       96      1   root             /sbin/init
    ```

7. Take a look at the ```pid ``` line - it this sample line, it indicates that 96 processes share the same view of the Process ID tree as /sbin/init does:

    ```
    4026531836 pid       96      1   root             /sbin/init
    ```

8. Let's start a shell that is in the root namespaces, except for the UTS (hostname) namespace.

    ```shell
    unshare --uts /bin/mysh
    ```

9. It looks like nothing has changed, but it has.  Set the hostname for the machine:

    ```shell
    hostname container
    ```

10. Ask what the hostname is:

    ```shell
    hostname
    ```

11. Now start a new terminal tab by hitting Ctrl-Shift-t.

    ```
    Hit Ctrl-Shift-t
    ```

12. Start a second SSH connection to the docker virtual machine, using the password `logidebtech` when prompted:

    ```shell
    ssh user@docker
    ```

13. In this connection, check the system's hostname. Is it "container?"

    ```shell
    hostname
    ```

14. Notice that the hostname on the system at large is still "docker."  Switch back to your original tab.

    ```
    Switch back to the previous terminal window/tab
    ``` 

15. So in this shell, we're in a different UTS (hostname) namespace from `init` and so many other processes. In this UTS namespace, the hostname is "container!" Check to see if the filesystem looks like a container by looking at the hostname file:

    ```shell
    cat /etc/hostname
    ```

16. No, it doesn't - this shell has the same filesystem as the main system.  Now, let's look at the namespace number for the one new namespace that we've created here, using lsns.

    ```shell
    lsns | grep mysh
    ```

17. Notice that the namespace number (in the first column) isn't the same as the one that /sbin/init was in. Also, notice that the second column says this namespace is a UTS (hostname) namespace. On a sample system, our output was:


    ```
    4026532550 uts         3 923316 root             mysh
    ```

18. Now exit the mysh shell, so we can see how things are in the original UTS namespace:

    ```shell
    exit
    ```

19. Run ```hostname``` to see the system hostname:

    ```shell
    hostname
    ```

20. See if there's still a separate namespace for the mysh program:

    ```shell
    lsns | grep mysh
    ```

21. You should see that the new UTS namespace no longer exists - it's closed down as soon as its initial process (```mysh```) exits.  On our sample system, this was the result of that command:

    ```
    root@docker:~# lsns | grep mysh
    root@docker:~# 
    ```

22. Think about how we can do this with the other namespaces that one associates with containers:

- Network (net)
- Control Group (cgroup)
- Process IDs (pid)
- User (user)
- Inter-process Communication (ipc)
- Filesysten (mnt)

There's another namespace that we won't be working with: the Time namepsace, which virtualizes two Linux clocks (CLOCK_BOOTTIME and CLOCK_MONOTONIC).


23. Let's explore two other namespaces, the PID namespace and the Mount (mnt) namespace. First, we'll need a filesystem. Download an alpine mini operating system root filesystem.

    ```shell
    urlpre="https://dl-cdn.alpinelinux.org/alpine/v3.18/releases/x86_64"
    file="alpine-minirootfs-3.18.2-x86_64.tar.gz"
    curl -LO "${urlpre}/${file}"
    ```

24. Next, create a `rootfs` directory for the filesystem to go in.

    ```shell
    mkdir rootfs
    ```

25. Finally, uncompress the alpine tarball into that directory.

    ```shell
    tar -xzvC rootfs -f $file
    ```

26. Now, create a new pid namespace:

    ```shell
    unshare --pid --fork sh
    ```

27. Create a new mount namespace for an `sh` shell process, centered on the rootfs folder:

    ```shell
    unshare --mount chroot rootfs sh
    ```

28. Check out the filesystem. This virtual machine is a Debian machine. Read the `/etc/os-release` file.

    ```shell
    cat /etc/os-release
    ```

29. Notice that the filesystem in this mount namespace has an `os-release` file that indicates Alpine Linux.

28. Next, let's create a new procfs in this directory:

    ```shell
    mount -t proc proc proc
    ```

30. Do a `ps` process listing to see all processes on the system:

    ```shell
    ps -ef
    ```

31. Notice that there are only a few visible processes and process ID (PID) 1 here is a shell, as opposed to `/sbin/init`.

32. This exercise is over.










