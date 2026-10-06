# frozen_string_literal: true

module Idv
  module ProofingAgent
    class AgentPiiForm
      include ActiveModel::Model
      include FormSsnFormatValidator

      REQUIRED_ATTRIBUTES = %i[first_name last_name dob email phone ssn id_type].freeze
      ATTRIBUTES = (%i[state_id residential_address passport] + REQUIRED_ATTRIBUTES).freeze

      ADDRESS_FIELD_RULES = {
        address1: { max: 255 },
        address2: { max: 255 },
        city: { max: 255 },
        state: { max: 64 },
        zip_code: { max: 10 },
      }.freeze

      FIELD_RULES = {
        email: { max: 255 },
        first_name: { max: 128 },
        last_name: { max: 128 },
        dob: { max: 10, date: true },
        phone: { max: 20 },
        ssn: { min: 9, max: 9, digits_only: true },
        id_type: { max: 20 },
      }.freeze

      NESTED_FIELD_RULES = {
        residential_address: ADDRESS_FIELD_RULES,
        state_id: {
          document_number: { max: 64 },
          jurisdiction: { max: 64 },
          expiration_date: { max: 10, date: true },
          issue_date: { max: 10, date: true },
          **ADDRESS_FIELD_RULES,
        },
      }.freeze

      validates_presence_of(*REQUIRED_ATTRIBUTES, message: 'cannot be blank')

      validate :field_rules_valid?
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

        attrs = %i[first_name last_name dob ssn dob_min_age] + document_attrs

        attrs.each do |k|
          keypaths << [:errors, k]
          keypaths << [:error_details, k]
          keypaths << [:error_details, k, k]
        end
        keypaths
      end

      private

      attr_reader(*ATTRIBUTES)

      # Checks each field against FIELD_RULES / NESTED_FIELD_RULES.
      # Nested fields are keyed as "parent.field" (e.g. "state_id.address1").
      def field_rules_valid?
        add_field_rule_errors(pii_from_agent, FIELD_RULES)

        NESTED_FIELD_RULES.each do |parent, rules|
          next if pii_from_agent[parent].blank?

          add_field_rule_errors(pii_from_agent[parent], rules, prefix: parent)
        end
      end

      def add_field_rule_errors(values, rules, prefix: nil)
        rules.each do |key, rule|
          field_errors(values[key], **rule).each do |type, message|
            errors.add(prefix ? :"#{prefix}.#{key}" : key, message, type:)
          end
        end
      end

      # Returns [[error_type, message], ...] for each rule the value violates.
      # Presence is validated separately, so blank values are skipped here.
      def field_errors(value, max: nil, min: nil, date: false, digits_only: false)
        return [] if value.blank?
        return [[:wrong_type, 'must be a string']] unless value.is_a?(String)

        violations = []
        if min && value.length < min
          violations << [:too_short, "is too short (minimum is #{min} characters)"]
        end
        if max && value.length > max
          violations << [:too_long, "is too long (maximum is #{max} characters)"]
        end
        if digits_only && !value.match?(/\A\d+\z/)
          violations << [:not_digits, 'must contain only digits']
        end
        if date && !valid_date_format?(value)
          violations << [:invalid_date, 'must be in YYYY-MM-DD format']
        end
        violations
      end

      def valid_date_format?(value)
        return false unless value.match?(/\A\d{4}-\d{2}-\d{2}\z/)

        Date.strptime(value, '%Y-%m-%d')
        true
      rescue Date::Error
        false
      end

      def dob_valid?
        # A malformed dob is reported by field_rules_valid? and would fail to parse here
        return if dob.blank? || errors.include?(:dob)

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
        when Idp::Constants::DocumentTypes::PASSPORT
          if !FeatureManagement.idv_proofing_agent_passport_enabled?
            errors.add(:unknown_id_type, 'unsupported id_type', type: :id_type)
            return
          end

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

        form = Pii::StateIdForm.new(state_id: state_id)
        return if form.valid?

        errors.merge!(form.errors)
      end

      def residential_address_valid?
        return if !residential_address_present?

        form = Pii::UspsStrictAddressForm.new(address: residential_address)
        return if form.valid?

        errors.merge!(form.errors)
      end

      def passport_valid?
        return if !passport_present?

        form = Pii::PassportForm.new(passport: passport)
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
