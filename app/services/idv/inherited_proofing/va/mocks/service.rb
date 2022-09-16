module Idv
  module InheritedProofing
    module Va
      module Mocks
        class Service
          VALID_AUTH_CODE = 'mocked-auth-code-for-testing'.freeze

          attr_reader :auth_code

          PAYLOAD_HASH = {
            first_name: 'Fakey',
            last_name: 'Fakerson',
            address: {
              street: '123 Fake St',
              street2: 'Apt 235',
              city: 'Faketown',
              state: 'WA',
              country: nil,
              zip: '98037',
            },
            phone: '2063119187',
            birth_date: '2022-1-31',
            ssn: '123456789',
            mhv_data: {
              mhvId: 99999999,
              identityProofedMethod: 'IPA',
              identityDocumentExist: true,
              identityProofingDate: '2020-12-14',
              identityDocumentInfo: {
                primaryIdentityDocumentNumber: '88888888',
                primaryIdentityDocumentType: 'StateIssuedId',
                primaryIdentityDocumentCountry: 'United States',
                primaryIdentityDocumentExpirationDate: '2222-03-30',
              },
            },
          }.freeze

          def initialize(auth_code)
            @auth_code = auth_code
          end

          def execute
            if (@auth_code != VALID_AUTH_CODE)
              raise TypeError,
                    "auth_code is invalid: #{@auth_code}"
            end

            PAYLOAD_HASH
          end
        end
      end
    end
  end
end
