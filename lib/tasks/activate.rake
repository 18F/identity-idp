namespace :deploy do
  desc 'Run activate script'
  task activate: :environment do
    require_relative '../deploy/activate'
    Deploy::Activate.new.run
  end
end
