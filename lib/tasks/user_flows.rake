unless Rails.env.production?
  namespace :spec do
    desc 'Executes user flow specs'
    RSpec::Core::RakeTask.new('user_flows') do |t|
      t.rspec_opts = %w[--tag user_flow
                        --order defined
                        --require ./lib/rspec/formatters/user_flow_formatter.rb
                        --format UserFlowFormatter]
    end

    desc 'Exports user flows for the web'
    task 'user_flows:web' do
      ENV['RAILS_DISABLE_ASSET_DIGEST'] = 'true'
      require './lib/user_flow_exporter'
      Rake::Task['spec:user_flows'].invoke
      UserFlowExporter.run
    end
  end
end
