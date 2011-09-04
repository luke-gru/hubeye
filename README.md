#Hubeye
<br />
Keep track of repositories on Github, get notified when they change and<br />
(optionally) run local system commands when new commits come in to Github.<br />
<br />

Hubeye is composed of a client and server. Once the server is run,<br />
you can connect to it via the client. Once connected, you'll be<br />
prompted by a '>'. Type the name of a Github repository.

Example: (what the user enters is preceded by the prompt)

    >hubeye
    commit  77b82b54044c16751228
    tree    8ce18af1461b5c741003
    parent  ea63fe317fe58dff1c95
    log tracking info for repos on client quit  => luke-gru

What you see is the latest commit reference, tree reference and parent<br />
commit reference on Github for that repository. Note that the user did<br />
not type a username. This is because the user defined a username in his<br />
~/.hubeye/hubeyerc file.

##Starting Hubeye

To start the server:

    >hubeye -s
or just

    >hubeye

This starts the server as a daemonized process. To run the server in<br />
your terminal (on <b>t</b>op):

    >hubeye -st

Hubeye runs on port 2000 be default. Change the port like this:

    >hubeye -sp 9001

To connect with the client:

    >hubeye -c

For more options:

    >hubeye -h


###~/.hubeye/hubeyerc

    username: luke-gru

This allows the user to type a repository name only, and to receive<br />
information regarding that <i>username</i>'s repository. The username<br />
should be a valid Github username.

###Keeping track of repositories

Hubeye doesn't actually track any repositories unless you disconnect<br />
from the server and leave the server running. This can be done by:

    >quit
    Bye!

If Hubeye has any repos to watch (track), it will watch Github for changes.<br />
It can keep track of as many repos as you want; just keep typing<br />
them in. If Hubeye finds a change to a repo, it will notify you of the<br />
changes using your Desktop notification system (libnotify, growl). It will<br />
also log the changes to your $HOME/.hubeye/log file. If the server is run<br />
in a terminal (-t option), the changes will also be logged to the terminal.<br
/>

To track your own repository, start the client in the root directory<br />
of your local git repo:

    >.

This only works if a <i>username</i> is added to the hubeyerc, and if the<br />
Github repository name is the same as the local root directory name.<br />
ie: '.' put in '/home/luke/code/hubeye' would track https://www.github.com/
luke-gru/hubeye<br />
if <i>username</i> was set to luke-gru.<br />

You can add another user's repo like this:

    >rails/rails

This adds https://github.com/rails/rails to the watch list.<br />
Hubeye does not remove a repo from the watch list unless explicitly<br />
told to do so:

    >rm luke-gru/hubeye

To see a list of all repos (with recent commit messages) in the watch (track) list:

    >tracking

###Desktop Notification
<i>On Linux: install libnotify-bin. On Mac: install growl (if not already installed).<br />
The autotest gem is needed for Desktop notification to work in both
cases.</i><br />

###Shutting down and persistence between sessions

    >shutdown

Next time you start up the server, the watch list will be empty<br />
(and so will the log file). In order to have a default watch list:

<i>~/.hubeye/hubeyerc</i>

    track: rails/rails, dchelimsky/rspec

These will be watched automatically when starting up the server.<br />

A way to interactively save all currently tracked repositories:

    >save repos as my_work_repos

And then load any time (even after a shutdown; next session, next week, etc...)

    >load repos my_work_repos

###Working with hooks

    >hook add rails/rails dir: /path/to/local/rails cmd: git pull origin master

When <b>https://www.github.com/rails/rails</b> changes, a process will start,
<br />
change to the selected directory and execute the command. The <i>(dir: /my/dir)
<br />
</i> part is optional, and when ignored won't change directories. In this
case,
<br />
the directory will be where the hubeye server was originally
started from.<br />

To see all currently loaded hooks:

    >hook list

To save all hooks for next sessions (after a server shutdown)

    >save hooks as weekend_projects_hooks

Then, next weekend:

    >load hooks weekend_projects_hooks

These hooks, of course, will only really do anything if the repositories they
<br />
are hooked to are currently being watched. This is not done automatically.

###All ~/.hubeyerc configurations

When the server is started, the options are set here.

    username: luke-gru
    track: username/reponame, username2/reponame2, myreponame
    oncearound = 90
    load hooks: myhook1, myworkhooks
    load repos: workprojects, funprojects
    desktop notification: on/off

<i>username</i>: username used for Github URLS when the full path is not
given<br />
inside of the client.<br />

<i>track</i>: default repositories to watch for changes upon server start<br />

<i>oncearound</i>: number of seconds before completing a check of every repo in<br />
the watch list for changes<br />

<i>load hooks</i>: load hooks on server start. To see how to save hooks in the
<br />
client, see the <i>Working with hooks</i> section<br />

<i>load repos</i>: load repos on server start. To see how to save repos in the
<br />
client, see the <i>Shutting down and persistence between sessions</i> section.
<br />

<i>desktop notification</i>: whether to notify of repo changes using libnotify
<br />
or growl. This is set to <i>on</i> by default. However, if no notification<br />
system is found, it is ignored.

