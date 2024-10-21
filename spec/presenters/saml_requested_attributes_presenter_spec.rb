require 'rails_helper'

RSpec.describe SamlRequestedAttributesPresenter do
  describe '#requested_attributes' do
    let(:service_provider_attribute_bundle) { %w[email all_emails] }
    let(:service_provider) do
      build(
        :service_provider,
        attribute_bundle: service_provider_attribute_bundle,
      )
    end
    let(:vtr) { nil }
    let(:ial) { Saml::Idp::Constants::AAL2_AUTHN_CONTEXT_CLASSREF }
    let(:authn_request_attribute_bundle) { %w[email] }

    subject do
      described_class.new(
        service_provider: service_provider,
        vtr:,
        ial:,
        authn_request_attribute_bundle: authn_request_attribute_bundle,
      )
    end

    context 'with identity proofing requested with VTR' do
      let(:authn_request_attribute_bundle) { %w[email first_name dob fake_extra_attribute] }
      let(:vtr) { ['C1.C2', 'C1.C2.P1'] }
      let(:ial) { nil }

      it 'returns requested proofing attributes' do
        expect(subject.requested_attributes).to eq(%i[email given_name birthdate])
      end

      context 'no attributes are requested' do
        let(:authn_request_attribute_bundle) { nil }
        let(:service_provider_attribute_bundle) { %w[email first_name ssn] }

        it 'returns default attributes' do
          expect(subject.requested_attributes).to eq(%i[email given_name social_security_number])
        end
      end
    end

    context 'with IAL2 requested with ACR values' do
      let(:authn_request_attribute_bundle) { %w[email first_name dob fake_extra_attribute] }
      let(:ial) { Saml::Idp::Constants::IAL2_AUTHN_CONTEXT_CLASSREF }

      it 'returns requested proofing attributes' do
        expect(subject.requested_attributes).to eq(%i[email given_name birthdate])
      end

      context 'no attributes are requested' do
        let(:authn_request_attribute_bundle) { nil }
        let(:service_provider_attribute_bundle) { %w[email first_name ssn] }

        it 'returns default attributes' do
          expect(subject.requested_attributes).to eq(%i[email given_name social_security_number])
        end
      end

      context 'with semantic acr values' do
        let(:ial) { Saml::Idp::Constants::IAL_VERIFIED_ACR }

        it 'returns requested proofing attributes' do
          expect(subject.requested_attributes).to eq(%i[email given_name birthdate])
        end

        context 'no attributes are requested' do
          let(:authn_request_attribute_bundle) { nil }
          let(:service_provider_attribute_bundle) { %w[email first_name ssn] }

          it 'returns default attributes' do
            expect(subject.requested_attributes).to eq(%i[email given_name social_security_number])
          end
        end
      end
    end

    context 'IALMax requested with ACR values' do
      let(:authn_request_attribute_bundle) { %w[email first_name dob fake_extra_attribute] }
      let(:ial) { Saml::Idp::Constants::IALMAX_AUTHN_CONTEXT_CLASSREF }

      it 'returns requested proofing attributes' do
        expect(subject.requested_attributes).to eq(%i[email given_name birthdate])
      end

      context 'no attributes are requested' do
        let(:authn_request_attribute_bundle) { nil }
        let(:service_provider_attribute_bundle) { %w[email first_name ssn] }

        it 'returns default attributes' do
          expect(subject.requested_attributes).to eq(%i[email given_name social_security_number])
        end
      end
    end

    context 'with address attributes requested' do
      let(:ial) { Saml::Idp::Constants::IAL_VERIFIED_ACR }
      let(:authn_request_attribute_bundle) { %w[address1 address2 city state zipcode] }

      it 'combines address fields into single friendly name' do
        expect(subject.requested_attributes).to eq(%i[address])
      end

      context 'with vtr values' do
        let(:acr_values) { nil }
        let(:vtr) { ['C1.C2.P1'] }

        it 'combines address fields into single friendly name' do
          expect(subject.requested_attributes).to eq(%i[address])
        end
      end
    end

    context 'no identity proofing requested' do
      let(:authn_request_attribute_bundle) { %w[email all_emails first_name fake_extra_attribute] }

      it 'filters requested attributes to non-proofing attributes' do
        expect(subject.requested_attributes).to eq(%i[email all_emails])
      end

      context 'no attributes are requested' do
        let(:authn_request_attribute_bundle) { nil }
        let(:service_provider_attribute_bundle) { %w[email first_name ssn verified_at] }

        it 'returns filtered default attributes' do
          expect(subject.requested_attributes).to eq(%i[email verified_at])
        end
      end
    end
  end
end
