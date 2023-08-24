require 'rails_helper'

RSpec.describe WebauthnVisitForm do
  include ActionView::Helpers::UrlHelper
  include Rails.application.routes.url_helpers

  let(:user) { build(:user) }
  let(:url_options) { {} }
  let(:in_mfa_selection_flow) { true }
  let(:form) do
    WebauthnVisitForm.new(
      user: user,
      url_options:,
      in_mfa_selection_flow: in_mfa_selection_flow,
    )
  end
  subject { form }

  describe '#submit' do
    it 'returns FormResponse with success: true if there are no errors' do
      params = {}

      expect(subject.submit(params).to_h).to eq(
        success: true,
        errors: {},
        platform_authenticator: false,
        enabled_mfa_methods_count: 0,
      )
    end

    context 'with platform authenticator' do
      it 'returns FormResponse with success: true if there are no errors' do
        params = { platform: 'true' }

        expect(subject.submit(params).to_h).to eq(
          success: true,
          errors: {},
          platform_authenticator: true,
          enabled_mfa_methods_count: 0,
        )
      end
    end

    context 'when there are errors' do
      it 'returns FormResponse with success: false with InvalidStateError' do
        params = { error: 'InvalidStateError' }
        errors = { InvalidStateError: [I18n.t('errors.webauthn_setup.already_registered')] }

        expect(subject.submit(params).to_h).to include(
          success: false,
          errors: errors,
          error_details: hash_including(*errors.keys),
        )
      end

      it 'returns FormResponse with success: false with NotSupportedError' do
        params = { error: 'NotSupportedError' }
        errors = { NotSupportedError: [I18n.t('errors.webauthn_setup.not_supported')] }

        expect(subject.submit(params).to_h).to include(
          success: false,
          errors: errors,
          error_details: hash_including(*errors.keys),
        )
      end

      it 'returns FormResponse with success: false with an unrecognized error' do
        params = { error: 'foo' }
        general_error = t(
          'errors.webauthn_setup.general_error_html',
          link_html: link_to(
            t('errors.webauthn_setup.additional_methods_link'),
            authentication_methods_setup_path,
          ),
        )
        errors = {
          foo: [general_error],
        }

        expect(subject.submit(params).to_h).to include(
          success: false,
          errors: errors,
          error_details: hash_including(*errors.keys),
        )
      end

      context 'with platform authenticator' do
        it 'returns FormResponse with success: false with InvalidStateError' do
          params = { error: 'InvalidStateError', platform: 'true' }
          errors = {
            InvalidStateError: [I18n.t('errors.webauthn_platform_setup.already_registered')],
          }

          expect(subject.submit(params).to_h).to include(
            success: false,
            errors: errors,
            error_details: hash_including(*errors.keys),
          )
        end

        it 'returns FormResponse with success: false with NotSupportedError' do
          params = { error: 'NotSupportedError', platform: 'true' }
          errors = { NotSupportedError: [I18n.t('errors.webauthn_platform_setup.not_supported')] }

          expect(subject.submit(params).to_h).to include(
            success: false,
            errors: errors,
            error_details: hash_including(*errors.keys),
          )
        end

        it 'returns FormResponse with success: false with an unrecognized error' do
          params = { error: 'foo', platform: 'true' }
          errors = { foo: [I18n.t(
            'errors.webauthn_platform_setup.account_setup_error',
            link: link_to(
              I18n.t('errors.webauthn_platform_setup.choose_another_method'),
              authentication_methods_setup_path,
            ),
          )] }

          expect(subject.submit(params).to_h).to include(
            success: false,
            errors: errors,
            error_details: hash_including(*errors.keys),
          )
        end

        context 'with two_factor_enabled' do
          let(:in_mfa_selection_flow) { false }
          let(:user) { create(:user, :with_phone) }

          it 'returns FormResponse with success: false with an unrecognized error' do
            params = { error: 'foo', platform: 'true' }
            errors = { foo: [I18n.t(
              'errors.webauthn_platform_setup.account_setup_error',
              link: I18n.t('errors.webauthn_platform_setup.choose_another_method'),
            )] }

            expect(subject.submit(params).to_h).to include(
              success: false,
              errors: errors,
              error_details: hash_including(*errors.keys),
            )
          end
        end
      end
    end
  end

  describe '#platform_authenticator?' do
    let(:params) { {} }

    before { subject.submit(params) }

    it { expect(subject.platform_authenticator?).to eq(false) }

    context 'with platform authenticator' do
      let(:params) { { platform: 'true' } }

      it { expect(subject.platform_authenticator?).to eq(true) }
    end
  end

  describe '#current_mfa_setup_path' do
    subject { form.current_mfa_setup_path }

    context 'with two_factor_enabled and in_mfa_selection_flow' do
      let(:user) { create(:user, :with_phone) }

      it { is_expected.to eq(authentication_methods_setup_path) }
    end

    context 'with two_factor_enabled' do
      let(:user) { create(:user, :with_phone) }
      let(:in_mfa_selection_flow) { false }

      it { is_expected.to eq(account_path) }
    end

    context 'with no prior mfa enabled' do
      it { is_expected.to eq(authentication_methods_setup_path) }
    end
  end
end
