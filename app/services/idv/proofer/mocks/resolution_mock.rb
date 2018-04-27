module Idv
  module Proofer
    module Mocks
      class ResolutionMock < ::Proofer::Base
        attributes :first_name, :last_name
        stage :resolution
        proof {}
      end
    end
  end
end
