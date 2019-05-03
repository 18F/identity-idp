class JobRun < ApplicationRecord
  validates :pid, presence: true

  after_initialize :set_default_values

  # Acquire exclusive read/write lock on whole table
  def self.with_lock
    raise ArgumentError, 'Must pass block' unless block_given?

    transaction do
      connection.execute(
        "LOCK #{table_name} IN ACCESS EXCLUSIVE MODE",
      )
      # Yield to caller block
      yield
    end
  end

  private

  def set_default_values
    Rails.logger.warn("Setting defaults")
    self.host = Socket.gethostname
    self.pid = Process.pid
  end
end
