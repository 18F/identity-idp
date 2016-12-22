require 'rails_helper'
require 'rake'

describe 'rotate' do
  describe 'attribute_encryption_key' do
    it 'runs successfully' do
      Rake.application.rake_require('lib/tasks/rotate', [Rails.root.to_s])
      Rake::Task.define_task(:environment)

      user = create(:user, phone: '555-555-5555')
      old_email = user.email
      old_phone = user.phone
      old_encrypted_email = user.encrypted_email
      old_encrypted_phone = user.encrypted_phone

      rotate_attribute_encryption_key

      Rake::Task['rotate:attribute_encryption_key'].invoke

      user.reload
      expect(user.phone).to eq old_phone
      expect(user.email).to eq old_email
      expect(user.encrypted_email).to_not eq old_encrypted_email
      expect(user.encrypted_phone).to_not eq old_encrypted_phone
    end
  end
end
