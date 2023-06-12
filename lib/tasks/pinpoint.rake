namespace :pinpoint do
  # benchmark: 100k updates in 00:28:35 with cost '800$8$1$'
  # e.g.
  #  bundle exec rake rotate:email_encryption_key
  #
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
  desc 'attribute encryption key'
  task update_supported_countries: :environment do
    require 'pinpoint_supported_countries'
    puts YAML.dump(PinpointSupportedCountries.new.run(sms_sender_id_country_codes: IdentityConfig.store.sender_id_country_codes))
  end
end
