module Idv
  module Proofer
    module Mocks
      class AddressMock < ::Proofer::Base
        attributes :first_name, :last_name
        stage :address
        proof {}
      end
    end
  end
end
