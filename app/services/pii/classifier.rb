# frozen_string_literal: true

module Pii
  class Classifier

    # @param [Pii::Attributes] pii
    # @return [boolean] whether it is for test request logging
    def self.pii_for_test_request_logging?(pii)
      !pii[:last_name].nil? && /.*_test_.*/i.match(pii[:last_name])
    end
  end
end
