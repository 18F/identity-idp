require 'rails_helper'

RSpec.describe SamlIdpExtensions::AssertionBuilder do
  let(:user) { create(:user, :fully_registered) }
  let(:endpoint) { SamlEndpoint.new(SamlEndpoint.suffixes.last) }
  let(:saml_request_id) { "_#{SecureRandom.uuid}" }
  let(:extra_options) { {} }
  let(:builder) do
    SamlIdp::AssertionBuilder.new(
      SecureRandom.uuid,
      SamlIdp.config.base_saml_location,
      user,
      'https://sp.example.gov',
      saml_request_id,
      'https://sp.example.gov/acs',
      SamlIdp.config.algorithm,
      Saml::Idp::Constants::IAL_VERIFIED_ACR,
      Saml::Idp::Constants::NAME_ID_FORMAT_PERSISTENT,
      endpoint.x509_certificate,
      endpoint.secret_key,
      Time.zone.now,
      60 * 60,
      nil,
      **extra_options,
    )
  end
  let(:doc) { Nokogiri::XML(builder.raw) }
  let(:ns) { { saml: Saml::XML::Namespaces::ASSERTION } }
  let(:confirmation_data) do
    doc.at_xpath(
      '/saml:Assertion/saml:Subject/saml:SubjectConfirmation/saml:SubjectConfirmationData', ns
    )
  end
  let(:conditions) { doc.at_xpath('/saml:Assertion/saml:Conditions', ns) }

  before do
    user.asserted_attributes = {
      uuid: { getter: ->(_principal) { 'pairwise-id' } },
      email: { getter: ->(_principal) { 'user@example.com' } },
    }
  end

  it 'is prepended to the gem class' do
    expect(SamlIdp::AssertionBuilder.ancestors.first).to eq(described_class)
  end

  context 'when answering an AuthnRequest, as every browser sign-in does' do
    it 'produces the same XML, byte for byte, as the gem method it replaces' do
      original_fresh = SamlIdp::AssertionBuilder.instance_method(:fresh).super_method

      freeze_time do
        expect(builder.raw).to eq(original_fresh.bind_call(builder))
      end
    end

    it 'still emits InResponseTo and the three-minute subject-confirmation window' do
      freeze_time do
        expect(confirmation_data['InResponseTo']).to eq(saml_request_id)
        expect(confirmation_data['NotOnOrAfter']).to eq(3.minutes.from_now.utc.iso8601)
      end
    end

    it 'signs the unchanged document with the endpoint key' do
      signed = XMLSecurity::SignedDocument.new(builder.signed)
      cert = OpenSSL::X509::Certificate.new(endpoint.x509_certificate)
      expect(signed.validate_document_with_cert(cert, false)).to eq(true)
    end
  end

  context 'without a request ID' do
    let(:saml_request_id) { nil }

    it 'omits InResponseTo rather than emitting an empty attribute' do
      expect(confirmation_data.attributes.keys).to eq(%w[NotOnOrAfter Recipient])
      expect(builder.raw).not_to include('InResponseTo')
      expect(confirmation_data['Recipient']).to eq('https://sp.example.gov/acs')
    end

    it 'keeps the three-minute default window' do
      freeze_time do
        expect(confirmation_data['NotOnOrAfter']).to eq(3.minutes.from_now.utc.iso8601)
      end
    end

    context 'with a caller-supplied subject-confirmation window' do
      let(:extra_options) { { subject_confirmation_expiry: 5 * 60 } }

      it 'uses it for SubjectConfirmationData and leaves Conditions at the assertion expiry' do
        freeze_time do
          expect(confirmation_data['NotOnOrAfter']).to eq(5.minutes.from_now.utc.iso8601)
          expect(conditions['NotOnOrAfter']).to eq(1.hour.from_now.utc.iso8601)
          expect(conditions['NotBefore']).to eq(5.seconds.ago.utc.iso8601)
        end
      end
    end

    context 'with a pinned issue instant' do
      let(:issue_instant) { Time.zone.parse('2026-10-09 14:00:00 UTC') }
      let(:extra_options) { { issue_instant:, subject_confirmation_expiry: 300 } }

      it 'counts IssueInstant and both windows from that instant, not from the clock' do
        travel_to(issue_instant + 20.seconds) do
          expect(doc.root['IssueInstant']).to eq('2026-10-09T14:00:00Z')
          expect(conditions['NotBefore']).to eq('2026-10-09T13:59:55Z')
          expect(conditions['NotOnOrAfter']).to eq('2026-10-09T15:00:00Z')
          expect(confirmation_data['NotOnOrAfter']).to eq('2026-10-09T14:05:00Z')
        end
      end
    end
  end
end
