class SidekiqLoggerFormatter < Logger::Formatter
  # This method is stdlib in ruby :reek:LongParameterList { max_params: 4 }
  def call(severity, time, progname, msg)
    msg = filter_msg(msg)
    super(severity, time, progname, msg)
  end

  private

  def filter_msg(msg)
    return filter_msg_string(msg) if msg.is_a? String
    return filter_msg_hash(msg) if msg.is_a? Hash
  end

  def filter_msg_string(msg)
    parsed = JSON.parse(msg)
    filter_msg_hash(parsed)
  rescue
    msg
  end

  def filter_msg_hash(msg)
    if msg.key?('job')
      msg['job']['args'].each { |arg| arg['arguments'] = '[redacted]' }
      msg['jobstr'] = '[redacted]'
    end
    msg
  end
end
