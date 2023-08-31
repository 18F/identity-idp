require 'rails_helper'

RSpec.describe DisplayablePiiFormatter do
  let(:last_sign_in_email_address) { 'test1@example.com' }
  let(:alternate_email_address) { 'test2@example.com' }
  let(:unconfirmed_email) { 'unconfirmed@example.com' }
  let(:email_addresses) do
    [
      build(:email_address, email: last_sign_in_email_address, last_sign_in_at: 1.second.ago),
      build(:email_address, email: alternate_email_address, last_sign_in_at: nil),
      build(:email_address, email: unconfirmed_email, last_sign_in_at: nil, confirmed_at: nil),
    ]
  end
  let(:verified_at) { 1.day.ago }
  let(:profiles) do
    if verified_at
      [build(:profile, :active, verified_at: verified_at)]
    else
      []
    end
  end
  let(:x509_subject) { 'foo' }
  let(:x509_issuer) { 'bar' }
  let(:piv_cac_configurations) do
    if x509_subject && x509_issuer
      [build(:piv_cac_configuration, x509_dn_uuid: x509_subject, x509_issuer: x509_issuer)]
    else
      []
    end
  end
  let(:first_name) { 'Testy' }
  let(:last_name) { 'Testerson' }
  let(:ssn) { '900123456' }
  let(:address1) { '123 main st' }
  let(:address2) { '' }
  let(:city) { 'Washington' }
  let(:state) { 'DC' }
  let(:zipcode) { '20405' }
  let(:dob) { '1990-01-01' }
  let(:phone) { '+12022121000' }

  let(:current_user) do
    create(
      :user,
      email_addresses: email_addresses,
      piv_cac_configurations: piv_cac_configurations,
      profiles: profiles,
    )
  end

  let(:pii) do
    {
      first_name: first_name,
      last_name: last_name,
      ssn: ssn,
      address1: address1,
      address2: address2,
      city: city,
      state: state,
      zipcode: zipcode,
      dob: dob,
      phone: phone,
    }
  end

  subject(:formatter) { described_class.new(current_user: current_user, pii: pii) }

  describe '#format' do
    context 'ial1' do
      let(:pii) { {} }

      it 'returns formatted ial1 PII' do
        result = formatter.format

        expect(result.email).to eq('test1@example.com')
        expect(result.all_emails).to match_array(['test1@example.com', 'test2@example.com'])
        expect(result.verified_at).to eq(I18n.l(verified_at, format: :event_timestamp))
        expect(result.x509_subject).to eq('foo')
        expect(result.x509_issuer).to eq('bar')
        expect(result.full_name).to be_nil
        expect(result.social_security_number).to be_nil
        expect(result.address).to be_nil
        expect(result.birthdate).to be_nil
        expect(result.phone).to be_nil
      end
    end

    context 'ial2' do
      it 'returns formatted ial2 PII' do
        result = formatter.format

        expect(result.email).to eq('test1@example.com')
        expect(result.all_emails).to match_array(['test1@example.com', 'test2@example.com'])
        expect(result.verified_at).to eq(I18n.l(verified_at, format: :event_timestamp))
        expect(result.x509_subject).to eq('foo')
        expect(result.x509_issuer).to eq('bar')
        expect(result.full_name).to eq('Testy Testerson')
        expect(result.social_security_number).to eq('900-12-3456')
        expect(result.address).to eq('123 main st Washington, DC 20405')
        expect(result.birthdate).to eq('January 1, 1990')
        expect(result.phone).to eq('+1 202-212-1000')
      end
    end

    describe '#verified_at' do
      context 'for a verified user' do
        let(:verified_at) { 1.day.ago }

        it 'returns the date the user was verified' do
          formatted_date = I18n.l(verified_at, format: :event_timestamp)
          expect(formatter.format.verified_at).to eq(formatted_date)
        end
      end
    end

    describe 'PIV/CAC attributes' do
      context 'the user has a piv/cac configured' do
        let(:x509_issuer) { 'foo' }
        let(:x509_subject) { 'bar' }

        it 'returns x509_issuer and x509_subject' do
          result = formatter.format
          expect(result.x509_issuer).to eq(x509_issuer)
          expect(result.x509_subject).to eq(x509_subject)
        end
      end

      context 'the user does not have a piv/cac configured' do
        let(:x509_issuer) { nil }
        let(:x509_subject) { nil }

        it 'returns nil for x509_issuer and x509_subject' do
          result = formatter.format
          expect(result.x509_issuer).to eq(nil)
          expect(result.x509_subject).to eq(nil)
        end
      end
    end

    describe '#address' do
      context 'without a second address line' do
        let(:address1) { '123 main st' }
        let(:address2) { '' }
        let(:city) { 'Washington' }
        let(:state) { 'DC' }
        let(:zipcode) { '20405' }

        it 'returns a formatted address' do
          expect(formatter.format.address).to eq('123 main st Washington, DC 20405')
        end
      end

      context 'with a second address line' do
        let(:address1) { '123 main st' }
        let(:address2) { 'apt 123' }
        let(:city) { 'Washington' }
        let(:state) { 'DC' }
        let(:zipcode) { '20405' }

        it 'returns a formatted address' do
          expect(formatter.format.address).to eq('123 main st apt 123 Washington, DC 20405')
        end
      end
    end

    context '#birthdate' do
      context 'with a YYYY-MM-DD dob' do
        let(:dob) { '1990-01-02' }

        it 'returns a formatted birdate' do
          formatted_date = I18n.l(DateParser.parse_legacy(dob), format: :long)
          expect(formatter.format.birthdate).to eq(formatted_date)
        end
      end

      context 'with a MM/DD/YYYY dob' do
        let(:dob) { '01/02/1990' }

        it 'returns a formatted birdate' do
          formatted_date = I18n.l(DateParser.parse_legacy(dob), format: :long)
          expect(formatter.format.birthdate).to eq(formatted_date)
        end
      end

      context 'with a non-English locale' do
        before { I18n.locale = :es }
        it 'returns a localized, formatted birthdate' do
          expect(formatter.format.birthdate).to eq('1 de enero de 1990')
        end
      end
    end

    context '#phone' do
      context 'with a phone number' do
        let(:phone) { '+12022121000' }

        it 'returns a formatted phone number' do
          expect(formatter.format.phone).to eq('+1 202-212-1000')
        end
      end

      context 'without a phone number' do
        let(:phone) { nil }

        it 'returns nil' do
          expect(formatter.format.phone).to be_nil
        end
      end
    end
  end
end
