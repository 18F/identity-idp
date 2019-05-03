namespace :job_runs do
  task run: :environment do
    puts 'Calling job runner'

    JobRunner::Runner.run
  end
end
