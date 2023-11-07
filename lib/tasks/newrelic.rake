namespace :newrelic do
  ##
  # This task is essentially the same as running the following:
  #
  #     bundle exec newrelic deployment -r $(git rev-parse HEAD)
  #
  # The reason for the rake task is that our `newrelic.yml` file contains ERB
  # blocks that expect the IdentityConfig to be setup and for identity-hostdata to be
  # loaded. This rake task loads the rails environment before reporting the
  # deployment so the NewRelic config is loaded correctly.
  #
  desc 'Report a new deployment to NewRelic'
  task deployment: :environment do
    require 'new_relic/cli/command'
    revision = `git rev-parse HEAD`.chomp
    NewRelic::Cli::Deployments.new(revision:).run
  end
end
