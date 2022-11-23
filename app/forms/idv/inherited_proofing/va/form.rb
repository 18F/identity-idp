module Idv
  module InheritedProofing
    module Va
      class Form < Idv::InheritedProofing::BaseForm
        REQUIRED_FIELDS = %i[first_name
                             last_name
                             birth_date
                             ssn
                             address_street
                             address_zip].freeze
        OPTIONAL_FIELDS = %i[phone
                             address_street2
                             address_city
                             address_state
                             address_country
                             service_error].freeze
        FIELDS = (REQUIRED_FIELDS + OPTIONAL_FIELDS).freeze

        attr_accessor(*FIELDS)
        validate :add_service_error, if: :service_error?
        validates(*REQUIRED_FIELDS, presence: true, unless: :service_error?)

        def submit
          extra = {}
          extra = { service_error: service_error } if service_error?

          FormResponse.new(
            success: validate,
            errors: errors,
            extra: extra,
          )
        end

        def user_pii
          raise 'User PII is invalid' unless valid?

          user_pii = {}
          user_pii[:first_name] = first_name
          user_pii[:last_name] = last_name
          user_pii[:dob] = birth_date
          user_pii[:ssn] = ssn
          user_pii[:phone] = phone
          user_pii[:address1] = address_street
          user_pii[:city] = address_city
          user_pii[:state] = address_state
          user_pii[:zipcode] = address_zip
          user_pii
        end

        def service_error?
          service_error.present?
        end

        private

        def add_service_error
          errors.add(
            :service_provider,
            # Use a "safe" error message for the model in case it's displayed
            # to the user at any point.
            I18n.t('inherited_proofing.errors.service_provider.communication'),
            type: :service_error,
          )
        end
      end
    end
  end
end
