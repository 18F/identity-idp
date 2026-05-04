# frozen_string_literal: true

module Idv
  module ProofingAgent
    class AgentPiiForm
      include ActiveModel::Model
      include FormSsnFormatValidator

      REQUIRED_ATTRIBUTES = %i[first_name last_name dob email phone ssn id_type].freeze
      ATTRIBUTES = (%i[state_id residential_address passport] + REQUIRED_ATTRIBUTES).freeze

      validates_presence_of(*REQUIRED_ATTRIBUTES, message: 'cannot be blank')

      validate :dob_valid?
      validate :id_type_valid?

      validate :state_id_xor_passport?
      validate :address_with_passport?
      validate :state_id_valid?
      validate :residential_address_valid?
      validate :passport_valid?

      attr_reader :pii_from_agent

      def initialize(pii:)
        @pii_from_agent = pii
        ATTRIBUTES.each do |attr|
          instance_variable_set("@#{attr}", pii[attr])
        end
      end

      def submit
        response = Idv::DocAuthFormResponse.new(
          success: valid?,
          errors:,
          extra: {
            pii_like_keypaths: self.class.pii_like_keypaths(document_type: id_type),
            document_type_received: id_type,
            id_issued_status: pii_from_agent.dig(:state_id, :issue_date).present? ?
                                'present' : 'missing',
            id_expiration_status: pii_from_agent.dig(:state_id, :expiration_date).present? ?
                                    'present' : 'missing',
            passport_issued_status: pii_from_agent.dig(:passport, :issue_date).present? ?
                                      'present' : 'missing',
            passport_expiration_status: pii_from_agent.dig(:passport, :expiration_date).present? ?
                                          'present' : 'missing',
          },
        )
        response.pii_from_doc = pii_from_agent
        response
      end

      def self.pii_like_keypaths(document_type:)
        keypaths = [[:pii]]
        is_passport = document_type&.downcase
          &.include?(Idp::Constants::DocumentTypes::PASSPORT)
        document_attrs = is_passport ?
                           %i[issue_date expiration_date issuing_country_code mrz] :
                           %i[address1 state zip_code jurisdiction document_number]

        attrs = %i[first_name last_name dob dob_min_age] + document_attrs

        attrs.each do |k|
          keypaths << [:errors, k]
          keypaths << [:error_details, k]
          keypaths << [:error_details, k, k]
        end
        keypaths
      end

      private

      attr_reader(*ATTRIBUTES)

      def dob_valid?
        return unless dob

        dob_date = DateParser.parse_legacy(dob)
        today = Time.zone.today
        age = today.year - dob_date.year - ((today.month > dob_date.month ||
          (today.month == dob_date.month && today.day >= dob_date.day)) ? 0 : 1)
        if age < IdentityConfig.store.idv_min_age_years
          errors.add(:dob_min_age, 'age does not meet minimum requirements', type: :dob)
        end
      end

      def id_type_valid?
        case id_type
        when *Idp::Constants::DocumentTypes::SUPPORTED_STATE_ID_TYPES
          return if state_id_present?

          errors.add(:state_id_type, 'mis-matched type vs data', type: :id_type)
        when *Idp::Constants::DocumentTypes::SUPPORTED_PASSPORT_TYPES
          return if passport_present?

          errors.add(:passport_type, 'mis-matched type vs data', type: :id_type)
        else
          errors.add(:unknown_id_type, 'unsupported id_type', type: :id_type)
        end
      end

      def state_id_xor_passport?
        if !(state_id_present? || passport_present?)
          errors.add(
            :base, :state_id_or_passport_blank,
            message: 'either state_id or passport must be present'
          )
        end
        if state_id_present? && passport_present?
          errors.add(
            :base, :state_id_and_passport,
            message: 'cannot include both state_id and passport'
          )
        end
      end

      def address_with_passport?
        if passport_present? && !residential_address_present?
          errors.add(
            :residential_address, :blank,
            message: 'residential address must be present with passport'
          )
        end
      end

      def state_id_valid?
        return if !state_id_present?

        form = StateIdForm.new(state_id: state_id)
        return if form.valid?

        errors.merge!(form.errors)
      end

      def residential_address_valid?
        return if !residential_address_present?

        form = AddressForm.new(address: residential_address)
        return if form.valid?

        errors.merge!(form.errors)
      end

      def passport_valid?
        return if !passport_present?

        form = PassportForm.new(passport: passport)
        return if form.valid?

        errors.merge!(form.errors)
      end

      def state_id_present?
        pii_from_agent[:state_id].present?
      end

      def passport_present?
        pii_from_agent[:passport].present?
      end

      def residential_address_present?
        pii_from_agent[:residential_address].present?
      end
    end
  end
end
