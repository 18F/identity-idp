namespace :service_providers do
  task backfill_help_texts: [:environment] do |_task|
    ServiceProvider.find_each do |sp|
      sp.update(help_text, { sign_in: {}, sign_up: {}, forgot_password: {} })
    end
  end
end