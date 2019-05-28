namespace :job_runs do
  task run: :environment do
    warn 'Calling job runner. See rails log for output.'

    loop do
      JobRunner::Runner.new.run
    end
  end
end
