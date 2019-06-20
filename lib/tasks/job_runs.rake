namespace :job_runs do
  task run: :environment do
    warn 'Calling job runner. See rails log for output.'

    keep_loop = true
    puts "rake job_runs:run with PID #{Process.pid}" if keep_loop

    `echo "#{Process.pid}" > #{Rails.root}/tmp/job_runs-0.pid`

    def shut_down
      `rm -rf #{Rails.root}/tmp/job_runs-0.pid`
      keep_loop = false
      puts "\nShutting down gracefully..." unless keep_loop
    end

    # Trap ^C
    Signal.trap('INT') do
      shut_down
      exit
    end

    # Trap `Kill `
    Signal.trap('TERM') do
      shut_down
      exit
    end

    JobRunner::Runner.new.run while keep_loop
  end
end
