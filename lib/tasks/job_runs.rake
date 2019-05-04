namespace :job_runs do
  task run: :environment do
    warn 'Calling job runner. See rails log for output.'

    JobRunner::Runner.run
  end
end
