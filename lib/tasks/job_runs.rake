namespace :job_runs do
  task :run, [:pidfile] => :environment do |_t, args|
    warn 'Calling job runner. See rails log for output.'
    @keep_jobs_loop = true
    @jobs_pid_file = nil

    # use provided pidfile path, if any
    @jobs_pid_file = args.pidfile

    warn "rake job_runs:run starting with PID #{Process.pid}"

    if @jobs_pid_file
      warn 'Writing to pidfile at ' + @jobs_pid_file.inspect
      File.write(@jobs_pid_file, Process.pid.to_s)
    end

    def shut_down
      File.unlink(@jobs_pid_file) if @jobs_pid_file
      @keep_jobs_loop = false
      Rails.logger.warn('Shutting down gracefully...')
      warn "\nShutting down gracefully..."
    end

    # Trap ^C
    Signal.trap('INT') do
      shut_down
    end

    while @keep_jobs_loop
      JobRunner::Runner.new.run

      # sleep 60, but bail out early if we are shutting down
      60.times do
        sleep 1
        break unless @keep_jobs_loop
      end
    end
  end
end
