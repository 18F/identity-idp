module Proofing
  module LexisNexis
    module Ddp
      class ResponseRedacter
        ALLOWED_RESPONSE_FIELDS = %w[
          fraudpoint.score
          request_id
          request_result
          review_status
          risk_rating
          summary_risk_score
          tmx_risk_rating
        ]

        def self.whilelist_response_and_redact_unwhitelisted_fields(response_json)
          begin
            hash = JSON.parse(response_json)
            whielisted_response_h = hash.slice(*ALLOWED_RESPONSE_FIELDS)
            unwhitelisted_fields = hash.keys - whielisted_response_h.keys
            unwhitelisted_fields.each do |key|
              whielisted_response_h[key] = '[redacted]'
            end
            whielisted_response_h
          rescue JSON::ParserError
            {}
          end
        end
      end
    end
  end
end
