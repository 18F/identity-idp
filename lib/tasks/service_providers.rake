namespace :service_providers do
  task :backfill_help_texts => [:environment] do |_task, args|
    ServiceProvider.find_each do |sp|
      sp.update_attribute(:help_text, { sign_in: {}, sign_up: {}, forgot_password: {} } )
    end
  end
end