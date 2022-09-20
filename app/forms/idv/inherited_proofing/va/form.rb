module Idv
  module InheritedProofing
    module Va
      class Form < Idv::InheritedProofing::Form
        class << self
          def fields
            @fields ||= {
              first_name: { required: true },
              last_name: { required: true },
              phone: { required: false },
              birth_date: { required: true },
              ssn: { required: true },
              address_street: { required: true },
              address_street2: { required: false },
              address_city: { required: false },
              address_state: { required: false },
              address_country: { required: false },
              address_zip: { required: true },
            }
          end
        end

        def user_pii
          raise 'User PII is invalid' unless valid?

          user_pii = payload_hash.dup
          user_pii[:dob] = user_pii.delete(:birth_date)
          # TODO: I think we need to add the address elements here.
          user_pii.delete(:address)
          user_pii.delete(:mhv_data)
          user_pii
        end
      end
    end
  end
end
