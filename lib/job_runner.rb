require 'new_relic/agent/tracer'

# Module for distributed cron job runner
#
# rubocop:disable Metrics/MethodLength, Metrics/AbcSize, Rails/TimeZone
module JobRunner
  # This class holds all of the known job configurations and is the entrypoint
  # for running all jobs.
  class Runner
    def self.configurations
      @configurations ||= []
    end

    def self.run
      Rails.logger.info("#{name}: Beginning job run")
      configurations.each do |c|
        Rails.logger.debug("Processing #{c.inspect}")
        c.clean_up_timeouts
        begin
          c.run_if_needed
        rescue StandardError
          # TODO: do some error handling, e.g. New Relic notice_error and then
          # keep going?
          raise
        end
      end
      Rails.logger.info("#{name}: Finished job run")
    end

    def self.run_loop
      raise NotImplementedError
    end
  end

  # A JobConfiguration defines a specific type of job along with how frequently
  # it should run.
  #
  class JobConfiguration
    attr_reader :name
    attr_reader :interval
    attr_reader :timeout
    attr_reader :callback

    # After initialization, the {JobConfiguration} will automatically append
    # itself to the list of configurations at {Runner.configurations}.
    #
    # @param [String] name The job name
    # @param [Integer] interval How often in seconds a job should run
    # @param [Integer] timeout The time in seconds after which to assume an
    #   incomplete job run failed
    # @param [Proc, Method, #call] callback The code to execute when the job is
    #   run
    def initialize(name:, interval:, timeout: 1.year, callback:)
      @name = name
      @interval = interval
      @timeout = timeout
      @callback = callback

      Runner.configurations << self
    end

    def to_s
      "JobConfiguration #{name.inspect}"
    end

    # Determine based on the JobRun history in the database whether the current
    # job is due to be run now.
    #
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
# rubocop:enable Metrics/MethodLength, Metrics/AbcSize, Rails/TimeZone
