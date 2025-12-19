require 'rails_helper'

RSpec.describe SocureErrorPresenter do
  include Rails.application.routes.url_helpers
  include ActionView::Helpers::UrlHelper
  include ActionView::Helpers::OutputSafetyHelper

  let(:error_code) { :network }
  let(:remaining_attempts) { 3 }
  let(:sp_name) { 'Test Service Provider' }
  let(:issuer) { 'urn:gov:gsa:openidconnect:sp:test' }
  let(:passport_requested) { false }
  let(:flow_path) { 'standard' }

  subject(:presenter) do
    described_class.new(
      error_code:,
      remaining_attempts:,
      sp_name:,
      issuer:,
      passport_requested:,
      flow_path:,
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

    context 'when error_code is :unexpected_id_type' do
      let(:error_code) { :unexpected_id_type }

      context 'when the passport is requested' do
        let(:passport_requested) { true }
        it 'returns the passport unexpected id type heading' do
          expect(presenter.heading).to eq(I18n.t('doc_auth.errors.verify_passport_heading'))
        end
      end

      context 'when the passport not requested' do
        let(:passport_requested) { false }
        it 'returns the passport unexpected id type heading' do
          expect(presenter.heading).to eq(I18n.t('doc_auth.errors.verify_drivers_license_heading'))
        end
      end
    end

    context 'when error_code is :network' do
      let(:error_code) { :network }

      it 'returns the network error heading' do
        expect(presenter.heading).to eq(I18n.t('doc_auth.headers.general.network_error'))
      end
    end

    context 'when error_code is :timeout' do
      let(:error_code) { :timeout }

      it 'returns the network error heading' do
        expect(presenter.heading).to eq(I18n.t('idv.errors.technical_difficulties'))
      end
    end

    context 'when error_code is :url_not_found' do
      let(:error_code) { :url_not_found }

      it 'returns the network error heading' do
        expect(presenter.heading).to eq(I18n.t('idv.errors.technical_difficulties'))
      end
    end

    context 'when error_code is :invalid_transaction_token' do
      let(:error_code) { :invalid_transaction_token }

      it 'returns the network error heading' do
        expect(presenter.heading).to eq(I18n.t('idv.errors.technical_difficulties'))
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

    context 'when error_code is :unexpected_id_type' do
      let(:error_code) { :unexpected_id_type }

      context 'when the passport is requested' do
        let(:passport_requested) { true }
        it 'returns the passport unexpected id type heading' do
          expect(presenter.body_text).to eq(
            safe_join(
              [
                I18n.t('doc_auth.errors.verify_passport_text'),
                link_to(
                  I18n.t('doc_auth.errors.verify.use_another_type_of_id'),
                  idv_choose_id_type_path,
                ),
              ],
              ' ',
            ),
          )
        end
      end

      context 'when the passport not requested' do
        let(:passport_requested) { false }
        it 'returns the passport unexpected id type heading' do
          expect(presenter.body_text).to eq(
            safe_join(
              [
                I18n.t('doc_auth.errors.verify_drivers_license_text'),
                link_to(
                  I18n.t('doc_auth.errors.verify.use_another_type_of_id'),
                  idv_choose_id_type_path,
                ),
              ],
              ' ',
            ),
          )
        end
      end
    end

    context 'when error_code is :network' do
      let(:error_code) { :network }

      it 'returns the network error message' do
        expect(presenter.body_text).to eq(I18n.t('doc_auth.errors.general.new_network_error'))
      end
    end

    context 'when error_code is :timeout' do
      let(:error_code) { :timeout }

      it 'returns the try again later error message' do
        expect(presenter.body_text).to eq(I18n.t('idv.errors.try_again_later'))
      end
    end

    context 'when error_code is :url_not_found' do
      let(:error_code) { :url_not_found }

      it 'returns the try again later error message' do
        expect(presenter.body_text).to eq(I18n.t('idv.errors.try_again_later'))
      end
    end

    context 'when error_code is :invalid_transaction_token' do
      let(:error_code) { :invalid_transaction_token }

      it 'returns the "internal error" error message' do
        expect(presenter.body_text).to eq(I18n.t('idv.failure.exceptions.internal_error'))
      end
    end

    context 'when error_code is underage' do
      let(:error_code) { 'underage' }

      before do
        allow(presenter).to receive(:remapped_error).with('underage').and_return('underage')
      end

      it 'returns the underage message with app name' do
        expect(presenter.body_text).to eq(
          I18n.t('doc_auth.errors.underage', app_name: APP_NAME),
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

  describe '#options' do
    subject { presenter.options }

    context 'when error code is timeout' do
      let(:error_code) { :timeout }

      it 'returns an empty array' do
        is_expected.to be_empty
      end
    end

    context 'when error code is url_not_found' do
      let(:error_code) { :url_not_found }

      it 'returns an empty array' do
        is_expected.to be_empty
      end
    end

    context 'when error code is invalid_transaction_token' do
      let(:error_code) { :invalid_transaction_token }

      it 'returns an empty array' do
        is_expected.to be_empty
      end
    end

    context 'when error code is not timeout or url_not_found' do
      let(:error_code) { :different_error }

      context 'when the flow path is hybrid' do
        let(:flow_path) { :hybrid }

        it 'returns an array of options including a hybrid flow choose id type option' do
          is_expected.to eq(
            [
              {
                url: '/verify/hybrid_mobile/choose_id_type',
                text: I18n.t('idv.troubleshooting.options.use_another_id_type'),
                isExternal: false,
              },
              {
                url: presenter.help_center_redirect_path(
                  category: 'verify-your-identity',
                  article: 'how-to-add-images-of-your-state-issued-id',
                ),
                isExternal: true,
                text: I18n.t('idv.troubleshooting.options.doc_capture_tips'),
              },
              {
                url: presenter.help_center_redirect_path(
                  category: 'verify-your-identity',
                  article: 'accepted-identification-documents',
                ),
                text: I18n.t('idv.troubleshooting.options.supported_documents'),
                isExternal: true,
              },
              {
                url: presenter.return_to_sp_failure_to_proof_url(step: 'document_capture'),
                text: t(
                  'idv.failure.verify.fail_link_html',
                  sp_name: sp_name,
                ),
                isExternal: true,
              },
            ],
          )
        end
      end

      context 'when the flow path is not hybrid' do
        let(:flow_path) { :standard }

        it 'returns an array of options including a standard flow choose_id_type option' do
          is_expected.to eq(
            [
              {
                url: '/verify/choose_id_type',
                text: I18n.t('idv.troubleshooting.options.use_another_id_type'),
                isExternal: false,
              },
              {
                url: presenter.help_center_redirect_path(
                  category: 'verify-your-identity',
                  article: 'how-to-add-images-of-your-state-issued-id',
                ),
                isExternal: true,
                text: I18n.t('idv.troubleshooting.options.doc_capture_tips'),
              },
              {
                url: presenter.help_center_redirect_path(
                  category: 'verify-your-identity',
                  article: 'accepted-identification-documents',
                ),
                text: I18n.t('idv.troubleshooting.options.supported_documents'),
                isExternal: true,
              },
              {
                url: presenter.return_to_sp_failure_to_proof_url(step: 'document_capture'),
                text: t(
                  'idv.failure.verify.fail_link_html',
                  sp_name: sp_name,
                ),
                isExternal: true,
              },
            ],
          )
        end
      end
    end
  end
end
