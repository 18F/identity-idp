# frozen_string_literal: true

module Proofing
  module LexisNexis
    Config = RedactedStruct.new(
      :instant_verify_workflow,
      :phone_finder_workflow,
      :account_id,
      :base_url,
      :username,
      :password,
      :hmac_key_id,
      :hmac_secret_key,
      :request_mode,
      :request_timeout,
      :org_id,
      :api_key,
      keyword_init: true,
      allowed_members: [
        :instant_verify_workflow,
        :phone_finder_workflow,
        :base_url,
        :request_mode,
        :request_timeout,
      ],
    )
  end
end
