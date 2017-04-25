require 'rails_helper'

describe ProfileIndex do
  let(:fake_pii) { Struct.new(:first_name) }
  let(:user) { build_stubbed(:user) }
  let(:decorated_user) { user.decorate }
  let(:decrypted_pii) { fake_pii.new('Alex') }

  describe '#header_personalization' do
    it 'returns an email address when user does not have a verified profile' do
      view_model = ProfileIndex.new(
        decrypted_pii: nil,
        personal_key: nil,
        decorated_user: decorated_user
      )

      expect(view_model.header_personalization).to eq(user.email)
    end

    it 'returns the users first name when they have a verified profile' do
      view_model = ProfileIndex.new(
        decrypted_pii: decrypted_pii,
        personal_key: nil,
        decorated_user: decorated_user
      )

      expect(view_model.header_personalization).to eq('Alex')
    end
  end
end
