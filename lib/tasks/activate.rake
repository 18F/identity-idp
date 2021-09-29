namespace :deploy do
  desc 'Run activate script'
  # rubocop:disable Rails/RakeEnvironment
  task :activate do
    require_relative '../deploy/activate'
    Deploy::Activate.new.run
  end
  # rubocop:enable Rails/RakeEnvironment
end
