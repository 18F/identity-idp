require 'rails_helper'

RSpec.describe Verify::Base do
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
