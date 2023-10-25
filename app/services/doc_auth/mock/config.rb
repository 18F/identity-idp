# frozen_string_literal: true

module DocAuth
  module Mock
    Config = RedactedStruct.new(
      :dpi_threshold,
      :sharpness_threshold,
      :glare_threshold, # required
      :warn_notifier,
      keyword_init: true,
      allowed_members: [
        :dpi_threshold,
        :sharpness_threshold,
        :glare_threshold,
      ],
    )
  end
end
