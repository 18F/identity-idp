require 'redacted_struct'

module IdentityDocAuth
  module Acuant
    # @!attribute [rw] exception_notifier
    #   @return [Proc] should be a proc that accepts an Exception and an optional context hash
    #   @example
    #      config.exception_notifier.call(RuntimeError.new("oh no"), attempt_count: 1)
    Config = RedactedStruct.new(
      :assure_id_password,
      :assure_id_subscription_id,
      :assure_id_url,
      :assure_id_username,
      :facial_match_url,
      :passlive_url,
      :timeout,
      :dpi_threshold,
      :sharpness_threshold,
      :glare_threshold,
      :exception_notifier,
      :warn_notifier,
      keyword_init: true,
      allowed_members: [
        :assure_id_subscription_id,
        :assure_id_url,
        :facial_match_url,
        :passlive_url,
        :timeout,
        :dpi_threshold,
        :sharpness_threshold,
        :glare_threshold,
      ]
    )
  end
end
