require 'spec_helper'

RSpec.describe Telephony::Util do
  describe '.duration_ms' do
    it 'is the duration in whole milliseconds between two times' do
      start  = Time.zone.at(1590609718.1231)
      finish = Time.zone.at(1590609719.999)

      expect(Telephony::Util.duration_ms(start: start, finish: finish)).to eq(1875)
    end
  end
end
