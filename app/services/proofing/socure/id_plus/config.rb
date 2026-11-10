# frozen_string_literal: true

module Proofing
  module Socure
    module IdPlus
      Config = RedactedStruct.new(
        :api_key,
        :base_url,
        :timeout,
        :user_uuid,
        :user_email,
        :bypasses_enabled,
        keyword_init: true,
        allowed_members: [
          :base_url,
          :timeout,
          :bypasses_enabled,
        ],
      ).freeze
    end
  end
end
