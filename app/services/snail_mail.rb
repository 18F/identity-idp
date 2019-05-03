class SnailMail
  def initialize
  end

  def daily_job_executed?
    sql_lock = 'LOCK job_runs IN ACCESS EXCLUSIVE MODE'
    jr = nil
    begin
      ActiveRecord::Base.transaction do
        ActiveRecord::Base.connection.execute(sql_lock)
        # Check last time job ran.  Insure the job has not run in last 24 hrs
        jr = JobRun.where(
          'finish_time < ?', (Time.zone.now - 24).to_datetime
        )
      end
    rescue StandardError => e
      puts "SQL error in #{__method__}"
      ActiveRecord::Base.connection.execute 'ROLLBACK'

      raise e
    end
    jr.blank?
  end

  def start_gpo_job
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
    end # if
  end
end
