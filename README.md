#Hubeye

Hubeye is composed of a client and server. Once the server is run,
you can connect to it via the client. Once connected, you'll be
prompted by a '>'. Type the name of a Github repository. 

Example: (what the user enters is preceded by the prompt)

    >hubeye
    commit  77b82b54044c16751228
    tree    8ce18af1461b5c741003
    parent  ea63fe317fe58dff1c95
    log tracking info for repos on client quit  => luke-gru

What you see is the latest commit reference, tree reference and parent 
commit reference on Github for that repository. Note that the user did 
not type a username. This is because the user defined a username in his
~/.hubeyerc file.

###~/.hubeyerc

    username = luke-gru

This allows the user to type the repository name only, and to receive
information regarding that user's repository. The username must be a 
valid Github username.

###Keeping track of repositories

Hubeye doesn't actually track any repositories unless you disconnect
from the server and leave the server running. This can be done by:

    >quit
    Bye!

If Hubeye has any repos to watch, it will watch Github for changes.
It can keep track of as many repos as you want; just keep typing
them in. If Hubeye finds a change in a repo, it will tell you that the
repo has changed in the terminal where the server is running. Also, next
time you connect to the server via the client, it will remind you. 
Hubeye does not remove a repo from the watch list unless explicitly 
told to do so.

    >rm luke-gru/hubeye

this removes luke-gru's hubeye repo from the watch list. You can also
add another user's repo like this:

    >rails/rails

This adds https://github.com/rails/rails to the watch list.

###Shutting down
    
    >shutdown

Next time you start up the server, the watch list is empty.
In order to have a default watch list:

~/.hubeyerc

    default = rails/rails | dchelimsky/rspec

These will be watched automatically when starting up the server

###All ~/.hubeyerc configurations

    username = luke-gru
    default = username/reponame | username2/reponame2 | myreponame
    oncearound = 90

oncearound: number of seconds before completing a check of every repo in
the watch list for changes

