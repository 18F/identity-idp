class FrontendErrorLogger
  class FrontendError < StandardError; end

  def self.track_error(name:, message:, stack:)
    NewRelic::Agent.notice_error(
      FrontendError.new,
      expected: true,
      custom_params: { name:, message:, stack: },
    )
  end
end
