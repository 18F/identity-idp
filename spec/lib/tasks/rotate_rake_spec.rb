require 'rails_helper'
require 'rake'

describe 'rotate' do
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
      old_email = user.email_addresses.first.email
      old_phone = user.phone_configurations.first.phone
      old_encrypted_email_address_email = user.email_addresses.first.encrypted_email
      old_encrypted_phone = user.phone_configurations.first.encrypted_phone

      rotate_attribute_encryption_key

      Rake::Task['rotate:attribute_encryption_key'].execute

      user.reload
      user.phone_configurations.reload
      expect(user.phone_configurations.first.phone).to eq old_phone
      expect(user.email_addresses.first.email).to eq old_email
      expect(user.email_addresses.first.encrypted_email).to_not eq old_encrypted_email_address_email
      expect(user.phone_configurations.first.encrypted_phone).to_not eq old_encrypted_phone
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
end
