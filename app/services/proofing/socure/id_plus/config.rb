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
        :is_proofing_agent,
        keyword_init: true,
        allowed_members: [
          :base_url,
          :timeout,
          :is_proofing_agent,
        ],
      ).freeze
    end
  end
end
