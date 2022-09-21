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
                                    address_country]
          end
        end

        validates(*required_fields, presence: true)

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
