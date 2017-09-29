class NoRetryJobs
  def call(_worker, msg, queue)
    yield
  rescue StandardError => _e
    msg['retry'] = false if queue == 'idv'
    raise
  end
end
