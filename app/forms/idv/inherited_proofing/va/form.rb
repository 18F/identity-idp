module Idv
  module InheritedProofing
    module Va
      class Form < Idv::InheritedProofing::BaseForm
        class << self
          def required_fields
            @required_fields ||= %i[first_name last_name birth_date ssn address_street address_zip]
          end

          def optional_fields
            @optional_fields ||= %i[phone address_street2 address_city address_state
                                    address_country network_error_raw network_error_safe
                                    service_provider_api_error]
          end
        end

        validates(*required_fields, presence: true, unless: :service_provider_api_error_or_network_error?)

        # Override the initializer - we probably don't want to mess with the base class
        # because other service providers may return errors in what may be a different
        # hash hierarchy.
        def initialize(payload_hash:)
          super

          if network_error?
            # TODO: Add to errors to #errors...
          end

          if service_provider_api_error?
            # TODO: Add to errors to #errors...
          end
        end

        def service_provider_api_error_or_network_error?
          network_error? || service_provider_api_error?
        end

        def network_error?
          network_error_raw.present?
        end

        def service_provider_api_error?
          # TODO: check for service provider api errors here return true/false
          service_provider_api_error.present?
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
      end
    end
  end
end
