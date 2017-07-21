require 'rails_helper'

RSpec.describe Verify::Base do
  describe '#mock_vendor_partial' do
    context 'idv vendor is mock' do
      it 'returns no pii warning partial' do
        allow(Figaro.env).to receive(:proofing_vendors).and_return('mock')

        partial = Verify::Base.new(remaining_attempts: 1, idv_form: nil).mock_vendor_partial

        expect(partial).to eq 'verify/sessions/no_pii_warning'
      end
    end

    context 'idv vendor is not mock' do
      it 'returns null partial' do
        allow(Figaro.env).to receive(:proofing_vendors).and_return('other')

        partial = Verify::Base.new(remaining_attempts: 1, idv_form: nil).mock_vendor_partial

        expect(partial).to eq 'shared/null'
      end
    end
  end

  describe '#message' do
    let(:timed_out) { false }
    let(:view_model) do
      Verify::Base.new(
        error: error,
        remaining_attempts: 1,
        idv_form: nil,
        timed_out: timed_out
      )
    end

    subject(:message) { view_model.message }

    before { expect(view_model).to receive(:step_name).and_return(:phone) }

    context 'with a warning' do
      let(:error) { 'warning' }

      it 'uses the warning copy' do
        expect(message).to include(t('idv.modal.phone.warning'))
      end

      context 'with a timeout' do
        let(:timed_out) { true }

        it 'uses the timeout copy' do
          expect(message).to include(t('idv.modal.phone.timeout'))
        end
      end
    end
  end
end
