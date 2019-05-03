class JobRun < ApplicationRecord
  validates :host, presence: true
  validates :pid, presence: true

  after_initialize :set_default_values

  # Run code with an exclusive read/write lock on the whole job_run table
  #
  # @yield Calls the provided block while the lock is held
  #
  def self.with_lock
    raise ArgumentError, 'Must pass block' unless block_given?

    transaction do
      connection.execute(
        "LOCK #{table_name} IN ACCESS EXCLUSIVE MODE",
      )
      # Yield to caller block with the lock held
      yield
    end
  end

  private

  # Set default attributes for the model
  def set_default_values
    self.host ||= Socket.gethostname
    self.pid ||= Process.pid
  end
end
