# frozen_string_literal: true

require 'date'

module Proofing
  module Aamva
    Applicant = Struct.new(
      :uuid,
      :first_name,
      :last_name,
      :dob,
      :state_id_data,
      :address1,
      :address2,
      :city,
      :state,
      :zipcode,
      keyword_init: true,
    ) do
      self::StateIdData = Struct.new(
        :state_id_number,
        :state_id_jurisdiction,
        :state_id_type,
        keyword_init: true,
      ).freeze

      # @return [Applicant]
      def self.from_proofer_applicant(applicant)
        new(
          uuid: applicant[:uuid],
          first_name: applicant[:first_name],
          last_name: applicant[:last_name],
          dob: format_dob(applicant[:dob]),
          state_id_data: format_state_id_data(applicant),
          address1: applicant[:address1],
          address2: applicant[:address2],
          city: applicant[:city],
          state: applicant[:state],
          zipcode: applicant[:zipcode]&.slice(0..4),
        )
      end

      private_class_method def self.format_dob(dob)
        return dob if /\A\d{4}-\d{2}-\d{2}\z/.match?(dob)
        return '' if dob.nil? || dob == ''

        date = date_from_dob_string(dob)

        return '' if date.nil?
        date.strftime('%Y-%m-%d')
      end

      private_class_method def self.date_from_dob_string(dob_string)
        if /\A\d{8}\z/.match?(dob_string)
          Date.strptime(dob_string, '%Y%m%d')
        elsif %r{\A\d{2}/\d{2}/\d{4}\z}.match?(dob_string)
          Date.strptime(dob_string, '%m/%d/%Y')
        end
      end

      # @return [StateIdData]
      private_class_method def self.format_state_id_data(applicant)
        self::StateIdData.new(
          state_id_number: applicant.dig(:state_id_number)&.gsub(/[^\w\d]/, ''),
          state_id_jurisdiction: applicant[:state_id_jurisdiction],
          state_id_type: applicant[:state_id_type],
        )
      end
    end.freeze
  end
end
