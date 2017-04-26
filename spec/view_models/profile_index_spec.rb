require 'rails_helper'

describe ProfileIndex do
  let(:unverified_view_model) { unverified_profile_index }

  describe '#header_partial' do
    it 'returns a basic header when user\'s identity is unverified' do
      expect(unverified_view_model.header_partial).to eq('profile/header')
    end

    it 'returns a verified header when user identity is verified' do
      view_model = verified_profile_index

      expect(view_model.header_partial).to eq('profile/verified_header')
    end
  end

  describe '#personal_key_partial' do
    it 'returns a null partial when a new personal key is not present' do
      expect_null_partial(unverified_view_model, 'personal_key_partial')
    end

    it 'returns personal_key partial when a new personal key is present' do
      view_model = unverified_profile_index(personal_key: '123')

      expect(view_model.personal_key_partial).to eq('profile/personal_key')
    end
  end

  describe '#password_reset_partial' do
    it 'returns null partial when reset password flag is not present' do
      expect_null_partial(unverified_view_model, 'password_reset_partial')
    end

    it 'returns password reset alert partial when password reset flag present' do
      user = create(:profile, deactivation_reason: 1).user.decorate
      view_model = ProfileIndex.new(
        decrypted_pii: nil,
        personal_key: nil,
        decorated_user: user
      )

      expect(view_model.password_reset_partial).to eq('profile/password_reset')
    end
  end

  describe '#pending_profile_partial' do
    it 'returns null partial when pending profile flag is not present' do
      expect_null_partial(unverified_view_model, 'pending_profile_partial')
    end

    it 'returns pending profile alert partial when pending profile flag present' do
      user = create(:profile, deactivation_reason: 3).user.decorate
      view_model = ProfileIndex.new(
        decrypted_pii: nil,
        personal_key: nil,
        decorated_user: user
      )

      expect(view_model.pending_profile_partial).to eq('profile/pending_profile')
    end
  end

  describe '#pii_partial' do
    it 'returns a null partial when the user is unverified' do
      expect_null_partial(unverified_view_model, 'pii_partial')
    end

    it 'returns pii partial when user is verified' do
      expect(verified_profile_index.pii_partial).to eq('profile/pii')
    end
  end

  describe '#edit_action_partial' do
    it 'returns edit action button partial' do
      expect(unverified_view_model.edit_action_partial).to(
        eq('profile/actions/edit_action_button')
      )
    end
  end

  describe '#personal_key_action_partial' do
    it 'returns manage personal key action partial' do
      expect(unverified_view_model.personal_key_action_partial).to(
        eq('profile/actions/manage_personal_key')
      )
    end
  end

  describe '#personal_key_item_partial' do
    it 'returns personal key item heading partial' do
      expect(unverified_view_model.personal_key_item_partial).to(
        eq('profile/personal_key_item_heading')
      )
    end
  end

  describe '#recent_event_partial' do
    it 'returns partial to format a single recent user event' do
      expect(unverified_view_model.recent_event_partial).to eq('profile/event_item')
    end
  end

  context 'totp related methods' do
    context 'with totp enabled' do
      before do
        user = build_stubbed(:user, otp_secret_key: '123').decorate
        @view_model = ProfileIndex.new(
          decrypted_pii: nil,
          personal_key: nil,
          decorated_user: user
        )
      end

      describe '#totp_partial' do
        it 'returns a partial to disable totp if active' do
          expect(@view_model.totp_partial).to eq('profile/actions/disable_totp')
        end
      end

      describe '#totp_content' do
        it 'returns auth app enabled message' do
          expect(@view_model.totp_content).to eq('profile.index.auth_app_enabled')
        end
      end
    end

    context 'with totp disabled' do
      describe '#totp_partial' do
        it 'returns a partial to enable totp' do
          expect(unverified_view_model.totp_partial).to eq('profile/actions/enable_totp')
        end
      end

      describe '#totp_content' do
        it 'returns auth app disabled message' do
          expect(unverified_view_model.totp_content).to eq('profile.index.auth_app_disabled')
        end
      end
    end
  end

  describe '#header_personalization' do
    it 'returns an email address when user does not have a verified profile' do
      user = unverified_view_model.decorated_user
      expect(unverified_view_model.header_personalization).to eq(user.email)
    end

    it 'returns the users first name when they have a verified profile' do
      expect(verified_profile_index.header_personalization).to eq('Alex')
    end
  end

  describe '#recent_events' do
    it 'exposes recent_events method from decorated_user' do
      expect(unverified_profile_index).to respond_to(:recent_events)
    end
  end
end

def verified_profile_index(personal_key: nil)
  profile = create(:profile, :active, :verified, pii: { first_name: 'Alex' })
  user = profile.user
  user_access_key = user.unlock_user_access_key(user.password)
  decrypted_pii = profile.decrypt_pii(user_access_key)

  ProfileIndex.new(
    decrypted_pii: decrypted_pii,
    personal_key: personal_key,
    decorated_user: user.decorate
  )
end

def unverified_profile_index(personal_key: nil)
  ProfileIndex.new(
    decrypted_pii: nil,
    personal_key: personal_key,
    decorated_user: unverified_decorated_user
  )
end

def expect_null_partial(view_model, method)
  expect(view_model.send(method.to_sym)).to eq('shared/null')
end

def unverified_decorated_user
  build_stubbed(:user).decorate
end
