require 'rails_helper'
require 'rake'

RSpec.describe 'rotate' do
  let(:user) { create(:user, :with_phone, with: { phone: '703-555-5555' }) }
  before do
    Rake.application.rake_require('lib/tasks/rotate', [Rails.root.to_s])
    Rake::Task.define_task(:environment)
    ENV['PROGRESS'] = 'no'
  end
  after do
    ENV['PROGRESS'] = 'yes'
  end

  describe 'attribute_encryption_key' do
    it 'runs successfully' do
      auth_app = create(:auth_app_configuration, user:)
      phone_number_opt_out = PhoneNumberOptOut.create_or_find_with_phone(
        Faker::PhoneNumber.cell_phone,
      )

      old_email = user.email_addresses.first.email
      old_phone = user.phone_configurations.first.phone
      old_otp_secret_key = auth_app.otp_secret_key
      old_encrypted_email_address_email = user.email_addresses.first.encrypted_email
      old_encrypted_phone = user.phone_configurations.first.encrypted_phone
      old_encrypted_otp_secret_key = auth_app.encrypted_otp_secret_key

      old_opt_out_phone = phone_number_opt_out.phone
      old_encrypted_opt_out_phone = phone_number_opt_out.encrypted_phone

      rotate_attribute_encryption_key

      Rake::Task['rotate:attribute_encryption_key'].execute

      user.reload
      user.phone_configurations.reload
      user.auth_app_configurations.reload
      expect(user.phone_configurations.first.phone).to eq old_phone
      expect(user.email_addresses.first.email).to eq old_email
      expect(user.auth_app_configurations.first.otp_secret_key).to eq old_otp_secret_key
      expect(user.email_addresses.first.encrypted_email).to_not eq old_encrypted_email_address_email
      expect(user.phone_configurations.first.encrypted_phone).to_not eq old_encrypted_phone
      expect(user.auth_app_configurations.first.encrypted_otp_secret_key).to_not eq(
        old_encrypted_otp_secret_key,
      )

      phone_number_opt_out.reload
      expect(phone_number_opt_out.phone).to eq old_opt_out_phone
      expect(phone_number_opt_out.encrypted_phone).to_not eq old_encrypted_opt_out_phone
    end

    it 'does not raise an exception when encrypting/decrypting a user' do
      allow_any_instance_of(EmailAddress).to receive(:email).and_raise(StandardError)

      expect do
        Rake::Task['rotate:attribute_encryption_key'].execute
      end.to_not raise_error
    end

    it 'outputs diagnostic information on users that throw exceptions ' do
      allow_any_instance_of(EmailAddress).to receive(:email).and_raise(StandardError)

      expect do
        Rake::Task['rotate:attribute_encryption_key'].execute
      end.to output(/Error with user id:#{user.id}/).to_stdout
    end
  end

  describe 'hmac_fingerprinter_key' do
    it 'runs successfully' do
      old_email = user.email_addresses.first.email
      old_email_fingerprint = user.email_addresses.first.email_fingerprint

      rotate_hmac_key

      Rake::Task['rotate:hmac_fingerprinter_key'].execute
      user.reload

      expect(user.email_addresses.first.email).to eq old_email
      expect(user.email_addresses.first.email_fingerprint).to_not eq(old_email_fingerprint)
      expect(EmailAddress.find_by(email_fingerprint: old_email_fingerprint)).to eq nil
      expect(
        EmailAddress.find_by(email_fingerprint: user.email_addresses.first.email_fingerprint).id,
      ).to eq user.email_addresses.first.id
    end
  end
end
