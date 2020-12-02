require 'rails_helper'

describe DataRequests::CreateMfaConfigurationsReport do
  describe '#call' do
    it 'includes an array for phone numbers' do
      user = create(:user)
      phone_configuration = create(:phone_configuration, user: user)

      result = described_class.new(user).call
      phone_data = result[:phone_configurations]

      expect(phone_data.first[:phone]).to eq(phone_configuration.phone)
      expect(phone_data.first[:created_at]).to be_within(1.second).of(
        phone_configuration.created_at,
      )
      expect(phone_data.first[:confirmed_at]).to be_within(1.second).of(
        phone_configuration.confirmed_at,
      )
    end

    it 'includes an array for authentication apps' do
      user = create(:user)
      auth_app_configuration = create(:auth_app_configuration, user: user)

      result = described_class.new(user).call
      auth_app_data = result[:auth_app_configurations]

      expect(auth_app_data.first[:name]).to eq(auth_app_configuration.name)
      expect(auth_app_data.first[:created_at]).to be_within(1.second).of(
        auth_app_configuration.created_at,
      )
    end

    it 'includes an array for security keys' do
      user = create(:user)
      webauthn_configuration = create(:webauthn_configuration, user: user)

      result = described_class.new(user).call
      webauthn_data = result[:webauthn_configurations]

      expect(webauthn_data.first[:name]).to eq(webauthn_configuration.name)
      expect(webauthn_data.first[:created_at]).to be_within(1.second).of(
        webauthn_configuration.created_at,
      )
    end

    it 'includes an array for piv/cac cards' do
      user = create(:user)
      piv_cac_configuration = create(:piv_cac_configuration, user: user)

      result = described_class.new(user).call
      piv_cac_data = result[:piv_cac_configurations]

      expect(piv_cac_data.first[:name]).to eq(piv_cac_configuration.name)
      expect(piv_cac_data.first[:created_at]).to be_within(1.second).of(
        piv_cac_configuration.created_at,
      )
    end

    it 'includes an array with backup codes' do
      user = create(:user)
      backup_code_configuration = create(
        :backup_code_configuration, user: user, used_at: Time.zone.now
      )

      result = described_class.new(user).call
      backup_code_data = result[:backup_code_configurations]

      expect(backup_code_data.first[:created_at]).to be_within(1.second).of(
        backup_code_configuration.created_at,
      )
      expect(backup_code_data.first[:used_at]).to be_within(1.second).of(
        backup_code_configuration.used_at,
      )
    end
  end
end
