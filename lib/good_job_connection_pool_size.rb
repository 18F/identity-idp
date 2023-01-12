class GoodJobConnectionPoolSize
  def self.calculate_worker_pool_size(queues:, cron_enabled:, max_threads:)
    queues = queues.split(';')
    # LISTEN/NOTIFY requires 1 connection
    connections = 1
    threads = queues.map do |queue|
      if queue != '*'
        _name, size = queue.split(':')
        Integer(size)
      else
        0
      end
    end.sum

    threads += max_threads if queues.include?('*')

    connections += threads

    # Cron requires two connections
    connections += 2 if cron_enabled

    connections
  end

  def self.calculate_primary_pool_size(queues:, max_threads:)
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

    connections += threads

    connections
  end
end
