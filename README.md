#Hubeye

<br />
Keep track of repositories on Github, get notified when they change and<br />
(optionally) run local system commands when new commits get pushed to certain
repositories.<br />
<br />

Hubeye is composed of a client and server. Once the server is run,<br />
you can connect to it via the client. Once connected, you'll be<br />
prompted by a '>'. Type in the name of a Github repository.

Example: (what the user enters is preceded by the prompt)

    > hubeye
    log tracking info for repos on client quit
    => luke-gru

What you see is the latest commit message and committer for that repository.<br />
Note that we did not type a username. This is because we defined <br />
a username in our ~/.hubeye/hubeyerc file.

Once a repo is in the watch list, typing it again will go and see if it has
changed.

    > hubeye
    Repository luke-gru/hubeye has not changed.

If, however, luke-gru/hubeye was pushed to since we last typed it in, <br />
it'll tell us that there have been changes, and what the new commit <br />
message is.

##Starting Hubeye

To start the server:

    > hubeye -s
or just

    > hubeye

This starts the server as a daemonized process. To run the server in<br />
your <b>t</b>erminal:

    > hubeye -st

Hubeye runs on port 4545 by default. Change the port like this:

    > hubeye -sp 9001

To connect using the client:

    > hubeye -c

For more options:

    > hubeye -h


##Basic ~/.hubeye/hubeyerc Configuration

    username: luke-gru

This allows the user to type a repository name only, and to receive<br />
information regarding that <i>username</i>'s repository. The username<br />
should be a valid Github username.

##Keeping Track of Repositories

You can add another user's repo like this:

    > rails/rails
or
    > add rails/rails

If you want to add multiple repos at once, use the<br />
<i>'add repo1 other_user/repo2 repo3 '</i> syntax

Hubeye doesn't actually enter its tracking loop unless you disconnect<br />
from the server and leave the server running. This can be done by:

    > quit
    Bye!

If Hubeye has any repos to track, it will watch Github for changes.<br />
It can keep track of as many repos as you want; just keep typing<br />
them in. If Hubeye finds a change to a repo, it will notify you of the<br />
changes using your Desktop notification system (libnotify, growl). It will<br />
also log the changes to your $HOME/.hubeye/log file. If the server is run<br />
in a terminal (-t option), the changes will also be logged there.<br />

Note that since the server is still running, you can connect to it using the<br />
client any time to add more repos to track, or to check the current commits.

To track your own repository, start the <i>client</i> in the root directory<br />
of your local git repo:

    > .

This only works if a <i>username</i> is added to the hubeyerc, and if the<br />
Github repository name is the same as the basename of $PWD<br />
ie: '.' put in '/home/luke/code/hubeye' would track https://www.github.com/luke-gru/hubeye
if <i>username</i> were set to luke-gru.<br />


This adds <b>https://github.com/rails/rails</b> to the watch list.<br />
Hubeye does not remove a repo from the watch list unless explicitly<br />
told to do so:

    > rm luke-gru/hubeye

To remove all tracked repos, simply:

    > rm -a

To see a list of all repos that Hubeye is tracking:

    > tracking

To see a more detailed list, including commit messages:

    > tracking -d

###Desktop Notification
<i>On Linux: install libnotify-bin. On Mac: install growl (if not already installed).<br />
The autotest gem is needed for Desktop notification to work with growl.<br />
Desktop notification is currently untested with growl, so please send error reports if<br />
you have any problems, or fork Hubeye and help out!</i>

###Shutting Down and Persistence between Sessions

    > shutdown

Next time you start up the server, the watch list will be empty<br />
(and so will the log file). In order to have a default watch list:

<i>~/.hubeye/hubeyerc</i>

    track: rails/rails, dchelimsky/rspec

These will be watched automatically when starting up the server.<br />

A way to interactively save all currently tracked repositories:

    > save repos as my_work_repos

And then load them any time (even after a shutdown, next session, next week, etc...)

    > load repos my_work_repos

This puts the repository names in the watch list with their most recent commits,
not the commits that were being tracked when you saved the repos.

###Working with Hooks

    > hook add rails/rails dir: /path/to/local/rails cmd: git pull origin master

When <b>https://www.github.com/rails/rails</b> changes, a process will start, <br />
change to the selected directory and execute the command. The <i>(dir: /my/dir)</i><br />
part is optional, and when ignored won't change directories. In that case,<br />
the directory in which the command is executed will be where the Hubeye server<br />
was originally started.<br />

If you want to call your own script with a hook and pass it the changed repo<br />
name, you can find the changed repo name by accessing <b>ENV['HUBEYE_CHANGED_REPO']</b><br />
in your script. Example:

    > hook add rails/rails dir: /path/to/email/script cmd: ./email_me.rb

In <i>email_me.rb</i>, <b>ENV['HUBEYE_CHANGED_REPO']</b> will be <i>rails/rails</i>.

To see all currently loaded hooks:

    > hook list

To save all hooks for next sessions (after a server shutdown)

    > save hooks as weekend_projects_hooks

Then, next weekend:

    > load hooks weekend_projects_hooks

These hooks, of course, will only really do anything if the repositories they <br />
are hooked to are currently being watched. This is not done automatically.

###All ~/.hubeye/hubeyerc Configurations

When the server is started, the options are set here.

    username: luke-gru
    track: username/reponame, username2/reponame2, myreponame
    oncearound: 90
    load hooks: myhook1, myworkhooks
    load repos: workprojects, funprojects
    desktop notification: on

<i>username</i>: username used for Github URLS when the full path is not <br />
given inside of the client <br />

<i>track</i>: default repositories to watch for changes upon server start<br />

<i>oncearound</i>: number of seconds before completing a check of every repo in <br />
the watch list for changes <br />

<i>load hooks</i>: hooks to load on server start. To see how to save hooks in the <br />
client, see the <i>Working with hooks</i> section <br />

<i>load repos</i>: repos to load on server start. To see how to save repos in the <br />
client, see the <i>Shutting down and persistence between sessions</i> section.
<br />

<i>desktop notification</i>: whether to notify of repo changes using libnotify <br />
or growl. This is set to <i>on</i> by default. However, if no notification<br />
system is found, it is ignored.
