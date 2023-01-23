# This class provides a starting point to dynamically calculate the number of database connections
# needed for our multi-threaded GoodJob deployment. Each process will create
# a certain number of threads based on configuration in the environment.
# The calculations here are guided by https://github.com/bensheldon/good_job/blob/8e7ac0cd47c0382544d99a6e2d7ee2a3053b2490/README.md#database-connections
class GoodJobConnectionPoolSize
  # Calculates the number of worker database connections the worker process needs.
  def self.calculate_worker_pool_size(queues:, cron_enabled:, max_threads:)
    # LISTEN/NOTIFY requires 1 connection
    connections = 1
    connections += num_explicit_threads_from_queues(queues: queues, max_threads: max_threads)

    # Cron requires two connections
    connections += 2 if cron_enabled

    connections
  end

  # Calculates the number of primary database connections the worker process needs.
  #
  # Each worker thread may need a primary database connection. We may not strictly need
  # one connection for each, but we will start there for safety.
  def self.calculate_primary_pool_size(queues:, max_threads:)
    num_explicit_threads_from_queues(queues: queues, max_threads: max_threads)
  end

  # The '*' queue will have up to `max_threads` threads. Other queues will use their explicitly
  # defined thread pool size.
  #
  # Example: 'low:1;high:2;*' with 5 max_threads would have up to 8 total threads.
  # Example: 'low:1;high:2' with 5 max_threads would have up to 3 total threads.
  def self.num_explicit_threads_from_queues(queues:, max_threads:)
    queues = queues.split(';')
    threads = queues.map do |queue|
      if queue != '*'
        _name, size = queue.split(':')
        Integer(size)
      else
        0
      end
    end.sum

    threads += max_threads if queues.include?('*')
    threads
  end
end
