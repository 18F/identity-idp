class FrontendErrorLogger
  class FrontendError < StandardError; end

  def track_error(name:, message:, stack:)
    NewRelic::Agent.notice_error(FrontendError.new, custom_params: { name:, message:, stack: })
  end
end
