module JobRunner
  class JobConfiguration
    attr_reader :name
    attr_reader :interval
    attr_reader :timeout
    attr_reader :callback

    def initialize(name:, interval:, timeout: 1.year, callback:)
      @name = name
      @interval = interval
      @timeout = timeout
      @callback = callback
    end

    def to_s
      "JobConfiguration #{name.inspect}"
    end

    # Determine based on the JobRun history in the database whether the current
    # job is due to be run now.
    # @return [Boolean]
    def run_needed?
      query = <<~SQL
        job_name = :name
        AND created_at > :interval_threshold
        AND ( finish_time IS NOT NULL OR created_at > :timeout_threshold )
      SQL

      jr = JobRun.where(
        query.squish,
        name: name,
        interval_threshold: Time.now.utc - interval,
        timeout_threshold: Time.now.utc - timeout,
      ).order('created_at DESC').first

      if jr.nil?
        true
      else
        Rails.logger.info("#{self}: Not yet due to run. Last run: #{jr.created_at}")
        false
      end
    end

    # Execute the job if a run is needed, otherwise return false.
    #
    # @return [false, JobRun] Return `false` if run was not scheduled, or a
    #   JobRun instance if the job was executed.
    def run_if_needed
      Rails.logger.info("#{self}: Checking if run is needed")

      return false unless run_needed?

      jr = nil

      # Acquire the lock and create the JobRun record
      JobRun.with_lock do
        # Recheck if run is needed with lock held to avoid race condition
        unless run_needed?
          Rails.logger.info("#{self}: Due for run, but someone else won the race")
          return false
        end

        Rails.logger.info("#{self}: Executing job")
        # Create JobRun record
        jr = JobRun.create!(job_name: name)
      end

      # Release the lock, execute the job code
      execute_job(jr: jr)

      Rails.logger.debug("#{self}: Done")

      jr
    end

    # Look for JobRun records that have timed out, find any that haven't
    # previously been handled, send notices for them, and then set their error
    # to be a timeout.
    def clean_up_timeouts
      Rails.logger.debug("#{self}: Looking for job timeouts to clean up")
      JobRun.clean_up_timeouts(job_name: name, timeout_threshold: Time.now.utc - timeout)
    end

    private

    # Actually run the job callback and record results
    #
    # @param [JobRun] jr
    def execute_job(jr:)
      raise ArgumentError, 'Expected JobRun object' unless jr.is_a?(JobRun)

      Rails.logger.debug("#{self}: executing callback")

      begin
        # Trace the runtime with New Relic
        ::NewRelic::Agent::Tracer.in_transaction(
          partial_name: "JobRun/execute/#{name}",
          category: :task,
        ) do

          # Call the callback and save the result
          jr.result = callback.call
        end
      rescue StandardError => e
        Rails.logger.warn("#{self}: Job failed: #{e.inspect}")
        jr.error = e.inspect
        jr.finish_time = Time.now.utc
        jr.save
        raise
      end

      Rails.logger.info("#{self}: Job finished successfully, saving result")
      jr.finish_time = Time.now.utc
      jr.save!
    end
  end
end
