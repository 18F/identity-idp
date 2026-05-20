# frozen_string_literal: true

module Idv
  class DobSsnForm
    include ActiveModel::Model
    include FormDobSsnValidator

    attr_accessor :ssn, :dob

    def self.model_name
      ActiveModel::Name.new(self, nil, 'doc_auth')
    end

    def initialize(pii)
      @pii = pii
    end

    def submit(ssn:, dob:)
      @ssn = ssn
      @dob = dob

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
  end
end
