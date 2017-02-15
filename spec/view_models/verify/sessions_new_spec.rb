require 'rails_helper'

RSpec.describe Verify::SessionsNew do
  describe '#mock_vendor_partial' do
    context 'idv vendor is mock' do
      it 'returns no pii warning partial' do
        allow(Figaro.env).to receive(:proofing_vendors).and_return('mock')

        partial = Verify::SessionsNew.new(remaining_attempts: 1).mock_vendor_partial

        expect(partial).to eq 'verify/sessions/no_pii_warning'
      end
    end

    context 'idv vendor is not mock' do
      it 'returns null partial' do
        allow(Figaro.env).to receive(:proofing_vendors).and_return('other')

        partial = Verify::SessionsNew.new(remaining_attempts: 1).mock_vendor_partial

        expect(partial).to eq 'shared/null'
      end
    end
  end
end
