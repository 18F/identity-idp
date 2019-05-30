class JobRun < ApplicationRecord
  validates :host, presence: true
  validates :pid, presence: true

  after_initialize :set_default_values

  def self.with_lock
    raise ArgumentError, 'Must pass block' unless block_given?
    transaction do
      connection.execute(
        "LOCK #{connection.quote_table_name(table_name)} IN ACCESS EXCLUSIVE MODE",
      )
      # Yield to caller block with the lock held
      yield
    end
  end

  def self.clean_up_timeouts(job_name:, timeout_threshold:)
    # Find all runs that did not finish and don't have an error recorded that
    # are older than the timeout threshold.
    where(job_name: job_name).where(finish_time: nil).where(error: nil).
      where('created_at < ?', timeout_threshold).lock.
      find_each(&:mark_as_timed_out)
  end

  def mark_as_timed_out
    return unless error.nil? && finish_time.nil? && result.nil?

    Rails.logger.debug("#{self.class.name}: Marking job #{id} as timed out")
    NewRelic::Agent.notice_error("JobRun timed out: #{inspect}")

    self.error = 'Timeout'
    save!

    self
  end

  private

  def set_default_values
    self.host ||= Socket.gethostname
    self.pid ||= Process.pid
  end
end
