# frozen_string_literal: true

require 'date'

module Proofing
  module Aamva
    Applicant = RedactedStruct.new(
      :uuid,
      :first_name,
      :last_name,
      :middle_name,
      :name_suffix,
      :dob,
      :height,
      :sex,
      :weight,
      :eye_color,
      :state_id_data,
      :address1,
      :address2,
      :city,
      :state,
      :zipcode,
      keyword_init: true,
    ) do
      self::StateIdData = RedactedStruct.new(
        :state_id_number,
        :state_id_jurisdiction,
        :id_doc_type,
        :state_id_issued,
        :state_id_expiration,
        keyword_init: true,
      ).freeze

      # @param applicant [Hash, Struct]
      # @option applicant [String, nil] :uuid
      # @option applicant [String, nil] :first_name
      # @option applicant [String, nil] :middle_name
      # @option applicant [String, nil] :last_name
      # @option applicant [String, nil] :name_suffix
      # @option applicant [String, nil] :dob
      # @option applicant [String, nil] :sex
      # @option applicant [Integer, nil] :height in inches
      # @option applicant [String, nil] :weight
      # @option applicant [String, nil] :eye_color
      # @option applicant [String, nil] :address1
      # @option applicant [String, nil] :address2
      # @option applicant [String, nil] :city
      # @option applicant [String, nil] :state
      # @option applicant [String, nil] :zipcode
      # @option applicant [String, nil] :state_id_number
      # @option applicant [String, nil] :state_id_jurisdiction
      # @option applicant [String, nil] :id_doc_type
      # @option applicant [String, nil] :state_id_issued
      # @option applicant [String, nil] :state_id_expiration
      # @return [Applicant]
      def self.from_proofer_applicant(applicant)
        new(
          uuid: applicant[:uuid],
          first_name: applicant[:first_name],
          last_name: applicant[:last_name],
          middle_name: applicant[:middle_name],
          name_suffix: applicant[:name_suffix],
          dob: format_dob(applicant[:dob]),
          sex: applicant[:sex],
          height: format_height(applicant[:height]),
          weight: applicant[:weight],
          eye_color: applicant[:eye_color],
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
          id_doc_type: applicant[:id_doc_type],
          state_id_issued: applicant[:state_id_issued],
          state_id_expiration: applicant[:state_id_expiration],
        )
      end

      private_class_method def self.format_height(height)
        return if height.nil?

        # From the AAMVA DLDV guide regarding formatting the height:
        # > Height data should be 3 characters (i.e. 5 foot 7 inches is submitted as 507)
        feet = (height / 12).floor
        inches = (height % 12).floor

        "#{feet}#{format('%02d', inches)}"
      end
    end.freeze
  end
end
