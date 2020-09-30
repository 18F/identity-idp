module Idv
  module Proofer
    @vendors = nil

    class << self
      def validate_vendors!
        resolution_vendor.new
        state_id_vendor.new
        address_vendor.new
      end

      def resolution_vendor
        if mock_fallback_enabled?
          ResolutionMock
        else
          LexisNexis::InstantVerify::Proofer
        end
      end

      def state_id_vendor
        if mock_fallback_enabled?
          StateIdMock
        else
          Aamva::Proofer
        end
      end

      def address_vendor
        if mock_fallback_enabled?
          AddressMock
        else
          LexisNexis::PhoneFinder::Proofer
        end
      end

      private

      def mock_fallback_enabled?
        Figaro.env.proofer_mock_fallback == 'true'
      end
    end
  end
end
