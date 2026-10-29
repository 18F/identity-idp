# frozen_string_literal: true

module TokenExchange
  module Constants
    GRANT_TYPE = 'urn:ietf:params:oauth:grant-type:token-exchange'
    ACCESS_TOKEN_TYPE = 'urn:ietf:params:oauth:token-type:access_token'
    CLIENT_ASSERTION_TYPE = 'urn:ietf:params:oauth:client-assertion-type:jwt-bearer'
    SCOPE = 'token_exchange'
    SCOPE_PREFIX = "#{SCOPE}:".freeze

    STAGE_ACTOR_AUTHORIZATION = 'actor_authorization'
    STAGE_SUBJECT_TOKEN = 'subject_token'
    STAGE_DELEGATED_TOKEN = 'delegated_token'

    # Matches the base `token_exchange` scope and audience-qualified variants,
    # for example `token_exchange:passport`.
    def self.in_scope?(value)
      value == SCOPE || value.to_s.start_with?(SCOPE_PREFIX)
    end
  end
end
