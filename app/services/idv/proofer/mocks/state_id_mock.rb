module Idv
  module Proofer
    module Mocks
      class StateIdMock < ::Proofer::Base
        attributes :first_name, :last_name
        stage :state_id
        proof {}
      end
    end
  end
end
