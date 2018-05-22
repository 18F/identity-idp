require 'rails_helper'

RSpec.describe Idv::Base do
  describe '#message' do
    let(:timed_out) { false }
    let(:view_model) do
      Idv::Base.new(
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

  describe '#modal_class_name' do
    let(:view_model) do
      Idv::Base.new(
        error: error,
        remaining_attempts: 1,
        idv_form: nil,
        timed_out: false
      )
    end

    subject(:modal_class_name) { view_model.modal_class_name }

    context 'when error is warning' do
      let(:error) { 'warning' }

      it 'returns modal_warning' do
        expect(modal_class_name).to eq 'modal-warning'
      end
    end

    context 'when error is jobfail' do
      let(:error) { 'jobfail' }

      it 'returns modal_warning' do
        expect(modal_class_name).to eq 'modal-warning'
      end
    end

    context 'when error is fail' do
      let(:error) { 'fail' }

      it 'returns modal_fail' do
        expect(modal_class_name).to eq 'modal-fail'
      end
    end
  end
end
