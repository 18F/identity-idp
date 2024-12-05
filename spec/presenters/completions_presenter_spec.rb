require 'rails_helper'

RSpec.describe CompletionsPresenter do
  include Rails.application.routes.url_helpers
  include ActionView::Helpers::OutputSafetyHelper
  include ActionView::Helpers::TagHelper

  let(:identities) do
    [
      build(
        :service_provider_identity,
        service_provider: current_sp.issuer,
        last_consented_at: nil,
      ),
    ]
  end
  let(:url_options) { {} }
  let(:current_user) { create(:user, :fully_registered, identities: identities) }
  let(:current_sp) { create(:service_provider, friendly_name: 'Friendly service provider') }
  let(:selected_email_id) { current_user.email_addresses.first.id }
  let(:decrypted_pii) do
    Pii::Attributes.new(
      first_name: 'Testy',
      last_name: 'Testerson',
      ssn: '900123456',
      address1: '123 main st',
      address2: 'apt 123',
      city: 'Washington',
      state: 'DC',
      zipcode: '20405',
      dob: '1990-01-01',
      phone: '+12022121000',
    )
  end
  let(:requested_attributes) do
    [
      :given_name, :family_name, :address, :phone, :email, :all_emails,
      :birthdate, :social_security_number, :x509_subject, :x509_issuer,
      :verified_at
    ]
  end
  let(:ial2_requested) { false }
  let(:completion_context) { :new_sp }

  subject(:presenter) do
    described_class.new(
      current_user:,
      current_sp:,
      decrypted_pii:,
      requested_attributes:,
      ial2_requested:,
      completion_context:,
      selected_email_id:,
      url_options:,
    )
  end

  describe '#heading' do
    context 'ial2 sign in' do
      let(:ial2_requested) { true }

      it 'renders the ial2 message' do
        expect(presenter.heading).to eq(
          I18n.t('titles.sign_up.completion_ial2', sp: current_sp.friendly_name),
        )
      end

      context 'renders the ial2 consent message if consent expired' do
        let(:identities) do
          [
            build(
              :service_provider_identity,
              service_provider: current_sp.issuer,
              last_consented_at: 2.years.ago,
            ),
          ]
        end
        let(:completion_context) { :consent_expired }

        it 'renders the expired consent message' do
          expect(presenter.heading).to eq(
            I18n.t('titles.sign_up.completion_consent_expired_ial2'),
          )
        end
      end
    end

    context 'first time the user signs into any SP' do
      it 'renders the first time sign in message' do
        expect(presenter.heading).to eq(
          I18n.t('titles.sign_up.completion_first_sign_in', sp: current_sp.friendly_name),
        )
      end
    end

    context 'consent has expired since the last sign in with ial1' do
      let(:identities) do
        [
          build(
            :service_provider_identity,
            service_provider: current_sp.issuer,
            last_consented_at: 2.years.ago,
          ),
        ]
      end
      let(:completion_context) { :consent_expired }

      it 'renders the expired consent message' do
        expect(presenter.heading).to eq(
          I18n.t('titles.sign_up.completion_consent_expired_ial1'),
        )
      end
    end

    context 'the sp has requested new attributes' do
      let(:identities) do
        [
          build(
            :service_provider_identity,
            service_provider: current_sp.issuer,
            last_consented_at: 1.day.ago,
          ),
        ]
      end
      let(:completion_context) { :new_attributes }

      it 'renders the new attributes message' do
        expect(presenter.heading).to eq(
          I18n.t('titles.sign_up.completion_new_attributes', sp: current_sp.friendly_name),
        )
      end
    end

    context 'the user is signing into an SP for the first time' do
      let(:identities) do
        [
          build(
            :service_provider_identity,
            service_provider: create(:service_provider).issuer,
            last_consented_at: 1.day.ago,
          ),
          build(
            :service_provider_identity,
            service_provider: current_sp.issuer,
            last_consented_at: nil,
          ),
        ]
      end
      let(:completion_context) { :new_sp }

      it 'renders the new sp message' do
        expect(presenter.heading).to eq(I18n.t('titles.sign_up.completion_new_sp'))
      end
    end
  end

  describe '#intro' do
    it 'renders the standard intro message' do
      expect(presenter.intro).to eq(
        t(
          'help_text.requested_attributes.intro_html',
          sp_html: content_tag(:strong, current_sp.friendly_name),
        ),
      )
    end

    context 'consent has expired since the last sign in' do
      let(:identities) do
        [
          build(
            :service_provider_identity,
            service_provider: current_sp.issuer,
            last_consented_at: 2.years.ago,
          ),
        ]
      end
      let(:completion_context) { :consent_expired }

      it 'renders the expired consent intro message' do
        expect(presenter.intro).to eq(
          safe_join(
            [
              t(
                'help_text.requested_attributes.consent_reminder_html',
                sp_html: content_tag(:strong, current_sp.friendly_name),
              ),
              t(
                'help_text.requested_attributes.intro_html',
                sp_html: content_tag(:strong, current_sp.friendly_name),
              ),
            ],
            ' ',
          ),
        )
      end
    end

    describe 'ial2' do
      let(:ial2_requested) { true }

      context 'consent has expired since the last sign in' do
        let(:identities) do
          [
            build(
              :service_provider_identity,
              service_provider: current_sp.issuer,
              last_consented_at: 2.years.ago,
            ),
          ]
        end
        let(:completion_context) { :consent_expired }

        it 'renders the expired consent intro message' do
          expect(presenter.intro).to eq(
            safe_join(
              [
                t(
                  'help_text.requested_attributes.consent_reminder_html',
                  sp_html: content_tag(:strong, current_sp.friendly_name),
                ),
                t(
                  'help_text.requested_attributes.intro_html',
                  sp_html: content_tag(:strong, current_sp.friendly_name),
                ),
              ],
              ' ',
            ),
          )
        end
      end

      context 'user has reverified since last consent for sp' do
        let(:identities) do
          [
            build(
              :service_provider_identity,
              service_provider: current_sp.issuer,
              last_consented_at: 2.months.ago,
            ),
          ]
        end
        let(:completion_context) { :reverified_after_consent }

        it 'renders the reverified IAL2 consent intro message' do
          expect(presenter.intro).to eq(
            t(
              'help_text.requested_attributes.ial2_reverified_consent_info_html',
              sp_html: content_tag(:strong, current_sp.friendly_name),
            ),
          )
        end
      end
    end
  end

  describe '#pii' do
    subject(:pii) { presenter.pii }

    context 'ial1' do
      context 'with a subset of attributes requested' do
        let(:requested_attributes) { [:email] }

        it 'properly scopes and resolve attributes' do
          expect(pii).to eq(email: current_user.email)
        end
      end

      context 'with email and all_emails requested' do
        let(:requested_attributes) { [:email, :all_emails] }

        it 'only displays all_emails' do
          expect(pii).to eq(all_emails: [current_user.email])
        end
      end

      context 'with all attributes requested' do
        it 'properly scopes and resolve attributes' do
          expect(pii).to eq(
            all_emails: [current_user.email],
            verified_at: nil,
            x509_issuer: nil,
            x509_subject: nil,
          )
        end

        it 'builds hash with sorted keys' do
          expect(pii.keys).to eq %i[
            all_emails
            x509_subject
            x509_issuer
            verified_at
          ]
        end
      end
    end

    context 'ial2' do
      let(:ial2_requested) { true }

      context 'with a subset of attributes requested' do
        let(:requested_attributes) { [:email, :given_name, :phone] }

        it 'properly scopes and resolve attributes' do
          expect(pii).to eq(
            email: current_user.email,
            full_name: 'Testy Testerson',
            phone: '+1 202-212-1000',
          )
        end

        it 'builds hash with sorted keys' do
          expect(pii.keys).to eq %i[
            email
            full_name
            phone
          ]
        end
      end

      context 'with all attributes requested' do
        it 'properly scopes and resolve attributes' do
          expect(pii).to eq(
            full_name: 'Testy Testerson',
            address: '123 main st apt 123 Washington, DC 20405',
            phone: '+1 202-212-1000',
            all_emails: [current_user.email],
            birthdate: 'January 1, 1990',
            social_security_number: '900-12-3456',
            verified_at: nil,
            x509_subject: nil,
            x509_issuer: nil,
          )
        end

        it 'builds hash with sorted keys' do
          expect(pii.keys).to eq %i[
            all_emails
            full_name
            address
            phone
            birthdate
            social_security_number
            x509_subject
            x509_issuer
            verified_at
          ]
        end
      end
    end
  end

  describe '#change_email_link' do
    context 'when user has multiple emails at completion screen' do
      let(:current_user) { create(:user, :fully_registered, :with_multiple_emails) }
      it 'returns link for sign up select email path' do
        expected_path = presenter.email_change_link
        expect(expected_path).to eq(sign_up_select_email_path)
      end
    end

    context 'when user has single email at completion screen' do
      it 'returns link for add_email path' do
        expected_path = presenter.email_change_link
        expect(expected_path).to eq(add_email_path(in_select_email_flow: true))
      end
    end
  end
end
