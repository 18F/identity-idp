# frozen_string_literal: true

module Idv
  class DobSsnForm
    include ActiveModel::Model
    include FormDobSsnValidator

    validate :dob_ssn_matches_applicant_pii

    attr_accessor :applicant, :ssn, :dob

    def self.model_name
      ActiveModel::Name.new(self, nil, 'doc_auth')
    end

    def initialize(applicant)
      @applicant = applicant
    end

    def submit(ssn:, dob:)
      @ssn = SsnFormatter.normalize(ssn) if ssn.present?
      @dob = MemorableDateComponent.extract_date_param(dob) if dob.present?

      FormResponse.new(
        success: valid?,
        errors:,
        extra: {
          pii_like_keypaths: [
            [:same_address_as_id],
            [:errors, :ssn],
            [:errors, :dob],
            [:error_details, :ssn],
            [:error_details, :dob],
          ],
        },
      )
    end

    def dob_ssn_matches_applicant_pii
      unless ssn_match? && dob_match?
        errors.add(:mismatch, I18n.t('idv.failure.dob_ssn.warning'), type: :mismatch)
      end
    end

    def dob_match?
      applicant[:dob] == dob
    end

    def ssn_match?
      applicant[:ssn] == ssn
    end
  end
end
