# frozen_string_literal: true

module Idv
  module ProofingAgent
    class SearchUserForm
      include ActiveModel::Model
      include FormSsnFormatValidator

      REQUIRED_ATTRIBUTES = %i[email ssn].freeze

      validates_presence_of(*REQUIRED_ATTRIBUTES, message: 'cannot be blank')

      def initialize(email:, ssn:)
        @email = email
        @ssn = ssn
      end

      def submit
        FormResponse.new(
          success: valid?,
          errors:,
        )
      end

      def self.pii_like_keypaths
        keypaths = []
        %i[email ssn].each do |k|
          keypaths << [:errors, k]
          keypaths << [:error_details, k]
          keypaths << [:error_details, k, k]
        end
        keypaths
      end

      private

      attr_reader :email, :ssn
    end
  end
end
