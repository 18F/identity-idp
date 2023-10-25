# frozen_string_literal: true

module DocAuth
  module Acuant
    Config = RedactedStruct.new(
      :assure_id_password,
      :assure_id_subscription_id,
      :assure_id_url,
      :assure_id_username,
      :facial_match_url,
      :passlive_url,
      :dpi_threshold,
      :sharpness_threshold,
      :glare_threshold,
      :warn_notifier,
      keyword_init: true,
      allowed_members: [
        :assure_id_subscription_id,
        :assure_id_url,
        :facial_match_url,
        :passlive_url,
        :dpi_threshold,
        :sharpness_threshold,
        :glare_threshold,
        :warn_notifier,
      ],
    )
  end
end
