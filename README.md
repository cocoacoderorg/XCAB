This is a set of (at least at the moment) shell scripts that manage a process whereby code can be modified from and uploaded to [Dropbox](http://www.dropbox.com/), at which point a Mac running these scripts will notice the Dropox changes, check those changes into git, build a new iOS executable from the git changes, push that executable to a web page, and send the user an email to come get it.

I'm currently using BetaBuilder to generate the ipa file, and using the [Boxcar](http://boxcar.io/) API to send push notifications.

You'll need to get [the command line version of BetaBuilder](git://github.com/sgruby/iOS-BetaBuilder.git), at least at the moment.

I've done some cleanup so it should be conceivable that it should work on someone else's machine (although, as far as I know, so far it never has).

I think what I've decided to do long term is to make a Mac MenuBar (NSStatusItem) based App and use NSTimer instead of running it from cron, and then work on moving a piece of it at a time from bash to Cocoa.  Then I'll make an iOS app to simplify what you have to do on the iOS side.
