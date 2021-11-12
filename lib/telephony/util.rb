module Telephony
  module Util
    # @param [Time] start
    # @param [Time] finish
    def self.duration_ms(start:, finish:)
      ((finish.to_f - start.to_f) * 1000.0).to_i
    end
  end
end
