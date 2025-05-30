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
        keyword_init: true,
        allowed_members: [
          :base_url,
          :timeout,
        ],
      ).freeze
    end
  end
end
