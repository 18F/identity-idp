module Idv
  module Proofer
    module Mocks
      class AddressMock < ::Proofer::Base
        attributes :phone

        stage :address

        proof do |applicant, result|
          plain_phone = applicant[:phone].gsub(/\D/, '').gsub(/\A1/, '')
          result.add_error(:phone, 'The phone number could not be verified.') if plain_phone == '5555555555'
        end
      end
    end
  end
end
