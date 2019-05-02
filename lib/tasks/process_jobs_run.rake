namespace :job_runs do
  task send_gpo_letters: :environment do
    puts 'Send GPO letters running'

    # Access exclusive lock on table
    sql_lock = "LOCK job_runs IN ACCESS EXCLUSIVE MODE"

    begin
      ActiveRecord::Base.transaction do
        ActiveRecord::Base.connection.execute(sql_lock)
        # Check last time job ran.  Insure the job has not run in last 24 hrs
        jr = JobRun.where(
          'finish_time < ?', (Time.zone.now - 24).to_datetime
        )
        # Check this datetime.  If now > 7pm, insert a new record
        if jr.blank? && Time.zone.now.hour > 19
          jr = JobRun.new
          jr.host = Socket.gethostname
          jr.pid = Process.pid
          jr.start_time = Time.zone.now
          jr.job_name = 'Send GPO Letters'

          # Insert record
          jr.save

          # Run actual uploader task
          UspsConfirmationUploader.new.run

          jr.finish_time = Time.zone.now
          jr.update
        end
      end
      # ActiveRecord::Base.connection.execute(sql_lock)
    rescue StandardError => e
      puts "SQL error in #{__method__}"
      ActiveRecord::Base.connection.execute 'ROLLBACK'

      raise e
    end
  end
end
# rake "job_runs:send_gpo_letters"
