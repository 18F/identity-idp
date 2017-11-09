class NoRetryJobs
  def call(_worker, msg, queue)
    yield
  rescue StandardError => _e
    msg['retry'] = false if %w[idv sms voice].include?(queue)
    raise
  end
end
