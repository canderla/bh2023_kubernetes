---
layout: exercise
exercise: 75
title: "Exercise: seccomp via Docker"
vm: rickmorty
tools: openssh-client netcat-traditional 
directories_to_sync: ssh-config 
---


## Steps

In this exercise, we're going to create a `seccomp` profile. `seccomp` profiles allow us to create an allow list of system calls that the program normally uses, then prevent the program from using system calls outside of that list. If the program is taken over by an attacker with an exploit, the system call limitation can either block the exploitation or make the compromised program far less useful for the attacker.

To keep this simple, we've created a program called `echoforeground` which we pretend is a trojan horse.  We're pretending that in its normal behavior, it should ask a question, give an answer, but never give away a text file.  We'll be doing this exercise with the RickdickulouslyEasy (`rickmorty`) CTF machine. The program listens on TCP port `22001`.

1. Start up a fresh lxterminal by clicking the "sparrow" logo in the bottom-left corner of the screen, clicking run, typing `lxterminal` and hitting enter. 

2. Connect to the service with netcat:

    ```shell
    nc rickmorty 22001
    ```

3. Type a few characters and hit enter to receive a "No - disconnect and try again" message.

4. Hit `Ctrl-C` to end the connection.

    ```
    Hit Ctrl-C
    ```

5. See if you can guess the password.  You may want to search for movie quotes. Make sure not to capitalize your answer or add any extra spaces to the beginning or end.  The password is [at the bottom of this page](#password-hint).

6. You'll see the `root` user's SSH private key file from this system displayed on the screen.  Write this private key into a file in your current directory named `rickmorty-key`. If you'd like to make this super easy, disconnect and then run this command:

    ```shell
    echo "mattersmost" | nc rickmorty 22001 >rickmorty-key
    ```

7. Run a `chmod go-rwx` on the rickmorty-key file, since `ssh` won't use a key file if its permissions are too open, then `ssh` into the `rickmorty` machine:

    ```shell
    chmod go-rwx rickmorty-key
    ssh -p 22222 -i rickmorty-key root@rickmorty
    ```

8. Let's block this attack by running that program with a custom Seccomp profile.

9. To make sure SELinux doesn't get in our way, let's put it in permissive mode.

    ```shell
    setenforce Permissive
    ```

10. Take a look at the `docker ps` listing - notice that port `22001` is actually routing to the same port number on a Docker container called `echoforeground`.  That container is running `echofg`.

    ```shell
    docker ps
    ```

11. Let's build a new container image for the `echoforeground` program, but have this one run `strace` to get a list of system calls that `echoforeground` uses.  We'll make the `entrypoint`, the program the container uses as PID 1, this:

    ```
    strace -ff /usr/local/sbin/echoforeground 22001
    ```

12. Switch into `/root/docker`:

    ```shell
    cd /root/docker
    ```

13. On this system, the `Dockerfile` is a symbolic link to `Dockerfile-echoforeground`.  Let's switch the symbolic link to point to `Dockerfile-strace` instead.

    ```shell
    ln -nsf Dockerfile-strace Dockerfile
    ```

14. Look at the difference between the two Dockerfiles by running:

    ```shell
    diff Dockerfile-echoforeground Dockerfile-strace
    ```

15. Observe that `Dockerfile-echoforeground` runs `echoforeground` directly, while `Dockerfile-strace` runs `strace`, which in turn runs `echoforeground`. Here's the output of the previous command on our test system:

    ```
    5,6c5,6
    < COPY id_rsa /root/.ssh/
    < ENTRYPOINT ["/usr/local/sbin/echoforeground","22001"]
    ---
    > COPY id_rsa /root/.ssh/id_rsa
    > ENTRYPOINT ["strace", "-ff", "/usr/local/sbin/echoforeground","22001"]
    ```

16. And now let's build a new image:

    ```shell
    docker build -t strace-echofg-image .
    ```

17. When you `strace` your program, you'll want to run the Docker container without any security confinement, so you get the program fully exercised and don't have the chance to miss anything.  We'll thus use `--security-opt label=disable` to prevent SELinux from acting, as well as `--security-opt seccomp=unconfined` to stop the default seccomp profile from acting. Finally, we'll use `--cap-add ALL` to prevent root capability confinement from blocking anything.

18. To avoid colliding with the current use of port `22001`, we'll remap the host's port `22002` to the container's port `22001`.  For our `strace`-profiling container, we'll thus run this:

    ```shell
    docker run -itd --name strace-echoforeground -p 22002:22001 \
      --security-opt label=disable --security-opt seccomp=unconfined \
      --cap-add ALL strace-echofg-image
    ```

19. Run `docker ps` to see the container running:

    ```shell
    docker ps
    ```
    
20. Observe that we see the new container, named `strace-echoforeground`. Here's the output from our test system:

    ```
    docker ps
    CONTAINER ID        IMAGE                 COMMAND                  CREATED              STATUS              PORTS                      NAMES
    e83b8f878f3c        strace-echofg-image   "/usr/local/sbin/e..."   14 seconds ago   	 Up 14 seconds   0.0.0.0:21002->21001/tcp   strace-echoforeground
    d79bfd70fa7e        echoforeground        "/usr/local/sbin/e..."   Up 30 minutes       Up 30 minutes      0.0.0.0:21001->21001/tcp   echoforeground
    ```

21. Now, let's connect to our `strace`-ing container from the `rickmorty` machine:

    ```shell
    nc 127.0.0.1 22002
    ```

22. Type anything but the proper password, so we don't get into the trojan horse code, then hit `Ctrl-C` to end the connection.

23. Next, gather the `strace` output from the `strace-echoforeground` container via docker logs:

    ```shell
    docker logs strace-echoforeground | \
    grep -v strace > strace-for-echofg
    ```

24. Now, let's parse that `strace` output into a `json` file that tells Docker what system calls should be permitted:

    ```shell
    ./parse-strace-to-json.sh strace-for-echofg >seccomp-echofg
    ```

25. Let's see how many syscalls are permitted in this new allowlist:

    ```shell
    grep name seccomp-echofg | wc -l
    ```

26. On our test system, the last command produced the number 17, indicating that this program can run using only 17 unique system calls. According to my syscall table, there are 314 system calls available before we use this allowlist. Our allowlist lets us restrict the program to well under 10% of those total 314 calls.

27. Now let's run a container from the same `echoforeground` that was already here running the service on TCP port `22001`. We'll place this one on TCP port `22003`. Here's a reference of what programs are on what port:

    ```
    Port	Name/Memo
    ----	---------
    22000	echodaemon, for SELinux exercise
    22001	echoforeground in Docker, w/o confinement
    22002	strace for echoforeground in Docker
    22003	echoforeground confined w/ seccomp
    ```

28. Start the container, using the new `seccomp` filter:

    ```shell
    docker run -itd --name confined-echofg -p 22003:22001 \
    --security-opt no-new-privileges \
    --security-opt seccomp=seccomp-echofg \
     --restart always echoforeground
    ```

29. Now connect to `localhost` port `22003` to connect to the `seccomp`-confined `echoforeground`.

    ```shell
    nc 127.0.0.1 22003
    ```

30. Let's make sure the program works by answering incorrectly and hitting `Ctrl-C` to terminate the connection.

31. Next, make sure that you've defeated the backdoor by reconnecting and entering the password.

    If you don't get an SSH key file back for the correct password, you're successful.

32. Suspend the virtual machines:

    ```shell
    sudo /sync/bin/suspend-all-vms.sh 
    ```

## Password Hint

The password is: `mattersmost`
