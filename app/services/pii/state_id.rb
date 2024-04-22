# frozen_string_literal: true


# rubocop:disable Style/MutableConstant
module Pii
  StateId = RedactedData.define(
    :first_name,
    :last_name,
    :middle_name,
    :address1,
    :address2,
    :city,
    :state,
    :dob,
    :state_id_expiration,
    :state_id_issued,
    :state_id_jurisdiction,
    :state_id_number,
    :state_id_type,
    :zipcode,
    :issuing_country_code,
  ) do
    def self.doc_auth_mock_pii(yaml_file_overrides = {})
      overrides = yaml_file_overrides&.symbolize_keys&.slice(*members) || {}
      new(**Idp::Constants::MOCK_IDV_APPLICANT.merge(overrides))
    end
  end
end
# rubocop:enable Style/MutableConstant
