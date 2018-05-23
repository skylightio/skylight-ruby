## Bug Reports and Feature Requests

If you've got a bug report or have a feature you'd like to request, please contact us at support@skylight.io or use the "?" button in the Skylight web interface. We'll be much quicker to respond that way :)

## Pull Requests

Before contributing, please [sign the CLA](https://docs.google.com/spreadsheet/viewform?usp=drive_web&formkey=dHJVY1M5bzNzY0pwN2dRZjMxV0dXSkE6MA#gid=0).

In general, we recommend that you speak with us about any new features you'd like to add so we can make sure we're on the same page.

## Emulating Travis Builds

We have many Travis build configurations that must pass in order to merge a pull request. You can emulate these configurations locally by running `rake run_travis_builds`. The only prerequisites are that you have both [VirtualBox](https://www.virtualbox.org/wiki/VirtualBox) and [Vagrant](https://www.vagrantup.com/) installed (most recent versions are best).

After that rake task completes, be sure to run `rake clobber compile`. This will delete the local native extension that was built when you ran `rake run_travis_builds` and rebuilds it.
