module Idv
  module InheritedProofing
    module Va
      class Form < DecoLite::Model
        validates :first_name, :last_name, :birth_date, :ssn, :address_street, :address_zip,
                  presence: true

        attr_reader :payload_hash

        def initialize(payload_hash:)
          raise ArgumentError, 'payload_hash is blank?' if payload_hash.blank?
          raise ArgumentError, 'payload_hash is not a Hash' unless payload_hash.is_a? Hash

          @payload_hash = payload_hash.dup

          super hash: @payload_hash
        end

        def submit
          validate

          FormResponse.new(
            success: valid?,
            errors: errors,
            extra: {},
          )
        end

        # Perhaps overkill, but a mapper service of some kind, not bound to this class,
        # that takes into consideration context, may be more suitable. In the meantime,
        # simply return a Hash suitable to place into flow_session[:pii_from_user] in
        # our inherited proofing flow steps.
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

        private

        attr_writer :payload_hash
      end
    end
  end
end
