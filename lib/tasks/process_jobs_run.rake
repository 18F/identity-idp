namespace :job_runs do
  task send_gpo_letters: :environment do
    puts 'Send GPO letters running'

    # Access exclusive lock on table
    sql_lock = "LOCK job_runs IN ACCESS EXCLUSIVE MODE"
    sn = SnailMail.new
    launch_job = sn.daily_job_executed?

    if launch_job && Time.zone.now.hour > 19
      sn.start_gpo_job
    end
  end
end
# rake "job_runs:send_gpo_letters"
