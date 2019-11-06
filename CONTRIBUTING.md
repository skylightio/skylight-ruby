## Bug Reports and Feature Requests

If you've got a bug report or have a feature you'd like to request, please contact us at support@skylight.io or use the "?" button in the Skylight web interface. We'll be much quicker to respond that way :)

## Pull Requests

Before contributing, please [sign the CLA](https://docs.google.com/spreadsheet/viewform?usp=drive_web&formkey=dHJVY1M5bzNzY0pwN2dRZjMxV0dXSkE6MA#gid=0).

In general, we recommend that you speak with us about any new features you'd like to add so we can make sure we're on the same page.

## Emulating Gitlab CI Builds

We have many CI build configurations that must pass in order to merge a pull request. You can run these individual configurations locally by running e.g., `gitlab-runner exec docker ruby23-rails42`. The only prerequisites are that you have both [Gitlab Runner](https://docs.gitlab.com/runner/) and [Docker](https://www.docker.com/) installed (most recent versions are best). Configuration names may be found in the `.gitlab.yml` file.

If you prefer to run tests in your own environment, you may do so as follows:

```shell
# Select a gemfile and bundle install
export BUNDLE_GEMFILE=$PWD/gemfiles/Gemfile.rails-5.2.x
bundle install
# Run the test suite (takes 5-10 minutes)
bundle exec rspec
```
