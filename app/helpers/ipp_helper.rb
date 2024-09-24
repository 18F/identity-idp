# frozen_string_literal: true

module IppHelper
  def scrub_message(message)
    message.gsub(/sponsorID \d+/i, 'sponsorID [FILTERED]')
  end

  def scrub_body(body)
    return nil if body.nil?

    if body.is_a?(String)
      scrub_message(body)
    else
      body = body.with_indifferent_access
      body[:responseMessage] = scrub_message(body[:responseMessage])
      body
    end
  end
end
