# frozen_string_literal: true

module Idv
  class SsnFormatForm
    include ActiveModel::Model
    include FormSsnFormatValidator

    attr_accessor :ssn

    def self.model_name
      ActiveModel::Name.new(self, nil, 'doc_auth')
    end

    def initialize(incoming_ssn)
      @ssn = incoming_ssn
      @updating_ssn = ssn.present?
    end

    def submit(ssn:)
      @ssn = ssn

      FormResponse.new(
        success: valid?,
        errors:,
        extra: {
          pii_like_keypaths: [
            [:same_address_as_id],
            [:errors, :ssn],
            [:error_details, :ssn],
          ],
        },
      )
    end

    def updating_ssn?
      @updating_ssn
    end
  end
end
