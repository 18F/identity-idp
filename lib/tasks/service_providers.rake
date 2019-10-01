namespace :service_providers do
  # rubocop:disable Rails/ActiveRecordAliases
  task backfill_help_texts: [:environment] do |_task|
    ServiceProvider.find_each do |sp|
      sp.update_attributes(help_text: { sign_in: {}, sign_up: {}, forgot_password: {} })
    end
  end
  # rubocop:enable Rails/ActiveRecordAliases
end
