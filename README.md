This is a set of (at least at the moment) shell scripts that manage a process whereby code can be modified from and uploaded to [Dropbox](http://www.dropbox.com/), at which point a Mac running these scripts will notice the Dropox changes, check those changes into git, build a new iOS executable from the git changes, push that executable to a web page, and send the user an email to come get it.

I'm currently using BetaBuilder to generate the ipa file, and expect to be using the boxcar API to to notifications soon.

There's a bunch of hardcoded junk in this thing that I need to fix, the cleanup is in process, but it isn't really ready for anyone else to use, yet. 