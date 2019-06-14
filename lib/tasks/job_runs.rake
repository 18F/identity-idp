namespace :job_runs do
  task run: :environment do
    warn 'Calling job runner. See rails log for output.'
    @keep_jobs_loop = true
    @jobs_pid_file = "#{Rails.root}/tmp/job_runs-0.pid"

    puts "rake job_runs:run with PID #{Process.pid}" if @keep_jobs_loop

    File.open(@jobs_pid_file, 'w') { |file| file.write(Process.pid) }

    def shut_down
      File.unlink(@jobs_pid_file)
      @keep_jobs_loop = false
      puts "\nShutting down gracefully..." unless @keep_jobs_loop
    end

    # Trap ^C
    Signal.trap('INT') do
      shut_down
    end

    # Trap `Kill `
    Signal.trap('TERM') do
      shut_down
    end

    while @keep_jobs_loop
      JobRunner::Runner.new.run
      unless @keep_jobs_loop
        exit
      end
    end
  end
end
