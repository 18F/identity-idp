require 'rails_helper'

describe CompletionsPresenter do
  let(:identities) do
    [
      build(
        :service_provider_identity,
        service_provider: current_sp.issuer,
        last_consented_at: nil,
      ),
    ]
  end
  let(:current_user) { create(:user, :signed_up, identities: identities) }
  let(:current_sp) { create(:service_provider, friendly_name: 'Friendly service provider') }
  let(:decrypted_pii) do
    {
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
    }
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
      current_user: current_user,
      current_sp: current_sp,
      decrypted_pii: decrypted_pii,
      requested_attributes: requested_attributes,
      ial2_requested: ial2_requested,
      completion_context: completion_context,
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
    end

    context 'first time the user signs into any SP' do
      it 'renders the first time sign in message' do
        expect(presenter.heading).to eq(
          I18n.t('titles.sign_up.completion_first_sign_in', sp: current_sp.friendly_name),
        )
      end
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

      it 'renders the expired consent message' do
        expect(presenter.heading).to eq(
          I18n.t('titles.sign_up.completion_consent_expired'),
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

  describe '#image_name' do
    context 'ial2 sign in' do
      let(:ial2_requested) { true }

      it 'renders the ial2 image' do
        expect(presenter.image_name).to eq('user-signup-ial2.svg')
      end
    end

    context 'ial1 sign in' do
      let(:ial2_requested) { false }

      it 'renders the ial1 image' do
        expect(presenter.image_name).to eq('user-signup-ial1.svg')
      end
    end
  end

  describe '#pii' do
    context 'ial1' do
      context 'with a subset of attributes requested' do
        let(:requested_attributes) { [:email] }

        it 'properly scopes and resolve attributes' do
          expect(presenter.pii).to eq(
            {
              email: current_user.email,
            },
          )
        end
      end

      context 'with email and all_emails requested' do
        let(:requested_attributes) { [:email, :all_emails] }

        it 'only displays all_emails' do
          expect(presenter.pii).to eq(
            {
              all_emails: [current_user.email],
            },
          )
        end
      end

      context 'with all attributes requested' do
        it 'properly scopes and resolve attributes' do
          expect(presenter.pii).to eq(
            {
              all_emails: [current_user.email],
              verified_at: nil,
              x509_issuer: nil,
              x509_subject: nil,
            },
          )
        end
      end
    end

    context 'ial2' do
      let(:ial2_requested) { true }

      context 'with a subset of attributes requested' do
        let(:requested_attributes) { [:email, :given_name, :phone] }

        it 'properly scopes and resolve attributes' do
          expect(presenter.pii).to eq(
            {
              email: current_user.email,
              full_name: 'Testy Testerson',
              phone: '+1 202-212-1000',
            },
          )
        end
      end

      context 'with all attributes requested' do
        it 'properly scopes and resolve attributes' do
          expect(presenter.pii).to eq(
            {
              full_name: 'Testy Testerson',
              address: '123 main st apt 123 Washington, DC 20405',
              phone: '+1 202-212-1000',
              all_emails: [current_user.email],
              birthdate: 'January 01, 1990',
              social_security_number: '900-12-3456',
              verified_at: nil,
              x509_subject: nil,
              x509_issuer: nil,
            },
          )
        end
      end
    end
  end
end
