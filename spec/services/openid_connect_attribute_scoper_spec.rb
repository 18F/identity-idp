require 'rails_helper'

RSpec.describe OpenidConnectAttributeScoper do
  subject(:scoper) { OpenidConnectAttributeScoper.new(scope) }

  describe '#scopes' do
    subject(:scopes) { scoper.scopes }

    context 'with a string of space-separate scopes' do
      let(:scope) { 'openid email profile' }

      it 'parses scopes' do
        expect(scopes).to eq(%w[openid email profile])
      end
    end

    context 'with an array' do
      let(:scope) { %w[fakescope openid email profile] }

      it 'filters the array' do
        expect(scopes).to eq(%w[openid email profile])
      end
    end
  end

  describe '#filter' do
    subject(:filtered) { scoper.filter(user_info) }

    let(:scope) { 'openid' }
    let(:verified_at) { Time.zone.parse('2020-01-01').to_i }
    let(:user_info) do
      {
        sub: 'abcdef',
        iss: 'https://login.gov',
        email: 'foo@example.com',
        email_verified: true,
        all_emails: ['foo@example.com', 'bar@example.com'],
        given_name: 'John',
        family_name: 'Jones',
        birthdate: '1970-01-01',
        phone: '+1 (703) 555-5555',
        phone_verified: true,
        address: {
          formatted: "123 Fake St\nWashington, DC 12345",
          street_address: '123 Fake St',
          locality: 'Washington',
          region: 'DC',
          postal_code: '12345',
        },
        social_security_number: '666661234',
        verified_at: verified_at,
      }
    end

    context 'minimum scope' do
      let(:scope) { 'openid' }

      it 'is only sub and iss' do
        expect(filtered).to eq(
          sub: 'abcdef',
          iss: 'https://login.gov',
        )
      end
    end

    context 'with address scope' do
      let(:scope) { 'openid address' }

      it 'includes the address attribute' do
        expect(filtered[:address]).to be_present
      end
    end

    context 'with email scope' do
      let(:scope) { 'openid email' }

      it 'includes the email and email_verified attributes' do
        expect(filtered[:email]).to be_present
        expect(filtered[:email_verified]).to eq(true)
        expect(filtered[:all_emails]).to be_nil
      end
    end

    context 'with the all_emails scope' do
      let(:scope) { 'openid all_emails' }

      it 'includes the all_emails attributes' do
        expect(filtered[:all_emails]).to eq(['foo@example.com', 'bar@example.com'])
      end
    end

    context 'with phone scope' do
      let(:scope) { 'openid phone' }

      it 'includes the phone and email_verified attributes' do
        expect(filtered[:phone]).to be_present
        expect(filtered[:phone_verified]).to eq(true)
      end
    end

    context 'with profile scope' do
      let(:scope) { 'openid profile' }

      it 'includes name attributes and birthdate' do
        expect(filtered[:given_name]).to be_present
        expect(filtered[:family_name]).to be_present
        expect(filtered[:birthdate]).to be_present
        expect(filtered[:verified_at]).to be_present
      end
    end

    context 'with profile:name scope' do
      let(:scope) { 'openid profile:name' }

      it 'includes name attributes' do
        expect(filtered[:given_name]).to be_present
        expect(filtered[:family_name]).to be_present
        expect(filtered[:birthdate]).to be_nil
        expect(filtered[:verified_at]).to be_nil
      end
    end

    context 'with profile:birthdate scope' do
      let(:scope) { 'openid profile:birthdate' }

      it 'includes name attributes' do
        expect(filtered[:given_name]).to be_nil
        expect(filtered[:family_name]).to be_nil
        expect(filtered[:birthdate]).to be_present
        expect(filtered[:verified_at]).to be_nil
      end
    end

    context 'with profile:verified_at scope' do
      let(:scope) { 'openid profile:verified_at' }

      it 'includes the verified_at attribute' do
        expect(filtered[:given_name]).to be_nil
        expect(filtered[:family_name]).to be_nil
        expect(filtered[:birthdate]).to be_nil
        expect(filtered[:verified_at]).to eq(verified_at)
      end
    end

    context 'with social_security_number scope' do
      let(:scope) { 'openid social_security_number' }

      it 'includes social_security_number' do
        expect(filtered[:social_security_number]).to be_present
      end
    end
  end

  describe '#requested_attributes' do
    subject(:requested_attributes) { scoper.requested_attributes }

    context 'with profile' do
      let(:scope) { 'email profile' }

      it 'is the array of attributes corresponding to the scopes' do
        expect(requested_attributes).to eq(%w[email given_name family_name birthdate verified_at])
      end
    end

    context 'with profile' do
      let(:scope) { 'email profile:birthdate' }

      it 'is the array of attributes corresponding to the scopes' do
        expect(requested_attributes).to eq(%w[email birthdate])
      end
    end
  end
end
