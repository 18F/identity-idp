module Idv::InheritedProofing::Va
  module Mocks
    class VaApiClient
      VALID_AUTH_CODE = 'mocked-auth-code-for-testing'.freeze

      USER_ATTRIBUTES = "{
        first_name: 'Fakey',
        last_name: 'Fakerson',
        address: {
          street: '123 Fake St',
          street2: 'Apt 235',
          city: 'Faketown',
          state: 'WA',
          country: nil,
          zip: '98037'
        },
        phone: '2063119187',
        birth_date: '2022-1-31',
        ssn: '123456789'
      }".freeze

      def initialize(auth_code)
        @auth_code = auth_code
      end

      def user_attributes
        raise TypeError, "Auth_code is invalid: #{@auth_code}" if (@auth_code != VALID_AUTH_CODE)

        response
      end

      private

      def response
        @response ||= Net::HTTP::Post.new('foo', 'Content-Type' => 'application/json')
        @response.body ||= { data: encrypted_user_attributes }.to_json
        @response
      end

      def encrypted_user_attributes
        JWE.encrypt(USER_ATTRIBUTES, private_key)
      end

      def private_key
        @private_key ||= AppArtifacts.store.oidc_private_key
      end
    end
  end
end
