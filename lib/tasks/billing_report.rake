namespace :reports do
  task :generate_billing_reports, %i[dest_dir year month auths_json sp_yml] =>
    [:environment] do |_task, args|
    Reports::BillingReport.new.call(
      dest_dir: args[:dest_dir],
      year: args[:year].to_i,
      month: args[:month].to_i,
      auths_json: args[:auths_json],
      sp_yml: args[:sp_yml],
    )
  end
end
