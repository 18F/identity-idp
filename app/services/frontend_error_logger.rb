# frozen_string_literal: true

class FrontendErrorLogger
  class FrontendError < StandardError; end

  def self.track_error(name:, message:, stack:, filename: nil, error_id: nil)
    return unless FrontendErrorForm.new.submit(filename:, error_id:).success?

    NewRelic::Agent.notice_error(
      FrontendError.new,
      expected: true,
      custom_params: { frontend_error: { name:, message:, stack:, filename:, error_id: } },
    )
  end
end
