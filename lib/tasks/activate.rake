namespace :deploy do
  desc 'Run activate script'
  # rubocop:disable [Rails/EnvironmentRakeTask] or something
  task :activate do
  # rubocop:enable [Rails/EnvironmentRakeTask] or something
    require_relative '../deploy/activate'
    Deploy::Activate.new.run
  end
end
