namespace :service_providers do
  # rubocop:disable Rails/SkipsModelValidations
  task backfill_help_texts: [:environment] do |_task|
    ServiceProvider.find_each do |sp|
      sp.update_attribute(:help_text, sign_in: {}, sign_up: {}, forgot_password: {})
    end
  end
  # rubocop:enable Rails/SkipsModelValidations
end
