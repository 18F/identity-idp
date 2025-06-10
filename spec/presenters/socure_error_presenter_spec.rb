require 'rails_helper'

RSpec.describe SocureErrorPresenter do
  let(:error_code) { :network }
  let(:remaining_attempts) { 3 }
  let(:sp_name) { 'Test Service Provider' }
  let(:issuer) { 'urn:gov:gsa:openidconnect:sp:test' }
  let(:flow_path) { 'standard' }

  subject(:presenter) do
    described_class.new(
      error_code: error_code,
      remaining_attempts: remaining_attempts,
      sp_name: sp_name,
      issuer: issuer,
      flow_path: flow_path,
    )
  end

  describe '#heading' do
    context 'when error_code is :selfie_fail' do
      let(:error_code) { :selfie_fail }

      it 'returns the selfie fail heading' do
        expect(presenter.heading).to eq(I18n.t('doc_auth.errors.selfie_fail_heading'))
      end
    end

    context 'when error_code is :unaccepted_id_type' do
      let(:error_code) { :unaccepted_id_type }

      it 'returns the unaccepted id type heading' do
        expect(presenter.heading).to eq(I18n.t('doc_auth.headers.unaccepted_id_type'))
      end
    end

    context 'when error_code is :network' do
      let(:error_code) { :network }

      it 'returns the network error heading' do
        expect(presenter.heading).to eq(I18n.t('doc_auth.headers.general.network_error'))
      end
    end

    context 'when error_code is a socure reason code' do
      let(:error_code) { 'R810' }

      before do
        allow(presenter).to receive(:remapped_error).with('R810').and_return('unreadable_id')
      end

      it 'returns the unreadable id heading' do
        expect(presenter.heading).to eq(I18n.t('doc_auth.headers.unreadable_id'))
      end
    end
  end

  describe '#body_text' do
    context 'when error_code is :selfie_fail' do
      let(:error_code) { :selfie_fail }

      it 'returns the selfie failure message' do
        expect(presenter.body_text).to eq(I18n.t('doc_auth.errors.general.selfie_failure'))
      end
    end

    context 'when error_code is :unaccepted_id_type' do
      let(:error_code) { :unaccepted_id_type }

      it 'returns the unaccepted id type message' do
        expect(presenter.body_text).to eq(I18n.t('doc_auth.errors.unaccepted_id_type'))
      end
    end

    context 'when error_code is :network' do
      let(:error_code) { :network }

      it 'returns the network error message' do
        expect(presenter.body_text).to eq(I18n.t('doc_auth.errors.general.new_network_error'))
      end
    end

    context 'when error_code is underage' do
      let(:error_code) { 'underage' }

      before do
        allow(presenter).to receive(:remapped_error).with('underage').and_return('underage')
      end

      it 'returns the underage message with app name' do
        expect(presenter.body_text).to eq(
          I18n.t('doc_auth.errors.underage', app_name: APP_NAME)
        )
      end
    end

    context 'when error_code is another socure reason code' do
      let(:error_code) { 'R827' }

      before do
        allow(presenter).to receive(:remapped_error).with('R827').and_return('expired_id')
      end

      it 'returns the mapped error message' do
        expect(presenter.body_text).to eq(I18n.t('doc_auth.errors.expired_id'))
      end
    end
  end
end