unless Rails.env.production?
  namespace :spec do
    desc 'Executes user flow specs'
    RSpec::Core::RakeTask.new('user_flows') do |t|
      t.rspec_opts = %w[--tag user_flow
                        --order defined
                        --require ./lib/rspec/formatters/user_flow_formatter.rb
                        --format UserFlowFormatter]
    end
  end
end
