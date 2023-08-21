namespace :service_providers do
  # rubocop:disable Rails/SkipsModelValidations
  task backfill_help_texts: [:environment] do |_task|
    ServiceProvider.find_each do |sp|
      sp.update_attribute(:help_text, sign_in: {}, sign_up: {}, forgot_password: {})
    end
  end

  task backfill_allow_prompt_login: [:environment] do |_task|
    ServiceProvider.find_each do |sp|
      sp.update_attribute(:allow_prompt_login, true)
    end
  end
  # rubocop:enable Rails/SkipsModelValidations

  # ISSUERS=123abc,456def rake service_providers:destroy_unused_providers
  desc 'Destroy unused providers'
  task destroy_unused_providers: :environment do
    require 'cleanup/destroy_unused_providers'

    issuers = ENV.fetch('ISSUERS', '').split(',')
    DestroyUnusedProviders.new(issuers).run
  end
end
