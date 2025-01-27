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
        errors: nil,
        platform_authenticator: false,
        enabled_mfa_methods_count: 0,
      )
    end

    context 'with platform authenticator' do
      it 'returns FormResponse with success: true if there are no errors' do
        params = { platform: 'true' }

        expect(subject.submit(params).to_h).to eq(
          success: true,
          errors: nil,
          platform_authenticator: true,
          enabled_mfa_methods_count: 0,
        )
      end
    end

    context 'when there are errors' do
      it 'returns FormResponse with success: false with InvalidStateError' do
        params = { error: 'InvalidStateError' }

        expect(subject.submit(params).to_h).to include(
          success: false,
          errors: nil,
          error_details: { InvalidStateError: { invalid: true } },
        )
      end

      it 'returns FormResponse with success: false with NotSupportedError' do
        params = { error: 'NotSupportedError' }

        expect(subject.submit(params).to_h).to include(
          success: false,
          errors: nil,
          error_details: { NotSupportedError: { invalid: true } },
        )
      end

      it 'returns FormResponse with success: false with an unrecognized error' do
        params = { error: 'foo' }

        expect(subject.submit(params).to_h).to include(
          success: false,
          error_details: { foo: { invalid: true } },
        )
      end

      context 'with platform authenticator' do
        it 'returns FormResponse with success: false with InvalidStateError' do
          params = { error: 'InvalidStateError', platform: 'true' }

          expect(subject.submit(params).to_h).to include(
            success: false,
            errors: nil,
            error_details: { InvalidStateError: { invalid: true } },
          )
        end

        it 'returns FormResponse with success: false with NotSupportedError' do
          params = { error: 'NotSupportedError', platform: 'true' }

          expect(subject.submit(params).to_h).to include(
            success: false,
            errors: nil,
            error_details: { NotSupportedError: { invalid: true } },
          )
        end

        it 'returns FormResponse with success: false with an unrecognized error' do
          params = { error: 'foo', platform: 'true' }

          expect(subject.submit(params).to_h).to include(
            success: false,
            errors: nil,
            error_details: { foo: { invalid: true } },
          )
        end

        context 'with two_factor_enabled' do
          let(:in_mfa_selection_flow) { false }
          let(:user) { create(:user, :with_phone) }

          it 'returns FormResponse with success: false with an unrecognized error' do
            params = { error: 'foo', platform: 'true' }

            expect(subject.submit(params).to_h).to include(
              success: false,
              errors: nil,
              error_details: { foo: { invalid: true } },
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
