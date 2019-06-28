require 'rails_helper'

describe AccountShow do
  describe '#verified_partial' do
    context 'user has a verified identity' do
      it 'returns the verified header partial' do
        user = User.new
        allow(user).to receive(:identity_verified?).and_return(true)
        profile_index = AccountShow.new(decrypted_pii: {}, personal_key: '', decorated_user: user)

        expect(profile_index.verified_account_badge_partial).to eq 'accounts/verified_account_badge'
      end
    end

    context 'user does not have a verified identity' do
      it 'returns the unverified header partial' do
        user = User.new
        allow(user).to receive(:identity_verified?).and_return(false)
        profile_index = AccountShow.new(decrypted_pii: {}, personal_key: '', decorated_user: user)

        expect(profile_index.verified_account_badge_partial).to eq 'shared/null'
      end
    end
  end

  describe '#personal_key_partial' do
    context 'AccountShow instance has a personal_key' do
      it 'returns the personal_key partial' do
        user = User.new
        profile_index = AccountShow.new(
          decrypted_pii: {}, personal_key: 'foo', decorated_user: user.decorate,
        )

        expect(profile_index.personal_key_partial).to eq 'accounts/personal_key'
      end
    end

    context 'AccountShow instance does not have a personal_key' do
      it 'returns the shared/null partial' do
        user = User.new
        profile_index = AccountShow.new(
          decrypted_pii: {}, personal_key: '', decorated_user: user.decorate,
        )

        expect(profile_index.personal_key_partial).to eq 'shared/null'
      end
    end
  end

  describe '#password_reset_partial' do
    context 'user has a password_reset_profile' do
      it 'returns the accounts/password_reset partial' do
        user = User.new.decorate
        allow(user).to receive(:password_reset_profile).and_return('profile')
        profile_index = AccountShow.new(
          decrypted_pii: {}, personal_key: 'foo', decorated_user: user,
        )

        expect(profile_index.password_reset_partial).to eq 'accounts/password_reset'
      end
    end

    context 'user does not have a password_reset_profile' do
      it 'returns the shared/null partial' do
        user = User.new
        allow(user).to receive(:password_reset_profile).and_return(nil)
        profile_index = AccountShow.new(
          decrypted_pii: {}, personal_key: '', decorated_user: user.decorate,
        )

        expect(profile_index.password_reset_partial).to eq 'shared/null'
      end
    end
  end

  describe '#pending_profile_partial' do
    context 'user needs profile usps verification' do
      it 'returns the accounts/pending_profile_usps partial' do
        user = User.new.decorate
        allow(user).to receive(:pending_profile_requires_verification?).and_return(true)
        profile_index = AccountShow.new(
          decrypted_pii: {}, personal_key: 'foo', decorated_user: user,
        )

        expect(profile_index.pending_profile_partial).to eq 'accounts/pending_profile_usps'
      end
    end

    context 'user does not need profile verification' do
      it 'returns the shared/null partial' do
        user = User.new.decorate
        allow(user).to receive(:pending_profile_requires_verification?).and_return(false)
        profile_index = AccountShow.new(decrypted_pii: {}, personal_key: '', decorated_user: user)

        expect(profile_index.pending_profile_partial).to eq 'shared/null'
      end
    end
  end

  describe '#pii_partial' do
    context 'AccountShow instance has decrypted_pii' do
      it 'returns the accounts/password_reset partial' do
        user = User.new.decorate
        profile_index = AccountShow.new(
          decrypted_pii: { foo: 'bar' }, personal_key: '', decorated_user: user,
        )

        expect(profile_index.pii_partial).to eq 'accounts/pii'
      end
    end

    context 'AccountShow instance does not have decrypted_pii' do
      it 'returns the shared/null partial' do
        user = User.new.decorate
        profile_index = AccountShow.new(decrypted_pii: {}, personal_key: '', decorated_user: user)

        expect(profile_index.pii_partial).to eq 'shared/null'
      end
    end
  end

  describe '#totp_partial' do
    context 'user has enabled an authenticator app' do
      it 'returns the disable_totp partial' do
        user = User.new
        allow_any_instance_of(
          TwoFactorAuthentication::AuthAppPolicy,
        ).to receive(:enabled?).and_return(true)
        allow_any_instance_of(
          MfaPolicy,
        ).to receive(:more_than_two_factors_enabled?).and_return(true)

        profile_index = AccountShow.new(
          decrypted_pii: {}, personal_key: '', decorated_user: user.decorate,
        )

        expect(profile_index.totp_partial).to eq 'accounts/actions/disable_totp'
      end
    end

    context 'user does not have an authenticator app enabled' do
      it 'returns the enable_totp partial' do
        user = User.new
        allow_any_instance_of(
          TwoFactorAuthentication::AuthAppPolicy,
        ).to receive(:enabled?).and_return(false)

        profile_index = AccountShow.new(
          decrypted_pii: {}, personal_key: '', decorated_user: user.decorate,
        )

        expect(profile_index.totp_partial).to eq 'accounts/actions/enable_totp'
      end
    end
  end

  describe '#header_personalization' do
    context 'AccountShow instance has decrypted_pii' do
      it "returns the user's first name" do
        user = User.new
        first_name = 'John'
        decrypted_pii = Pii::Attributes.new_from_json({ first_name: first_name }.to_json)
        profile_index = AccountShow.new(
          decrypted_pii: decrypted_pii, personal_key: '', decorated_user: user.decorate,
        )

        expect(profile_index.header_personalization).to eq first_name
      end
    end

    context 'AccountShow instance does not have decrypted_pii' do
      it 'returns the email the user used to sign in last' do
        decorated_user = create(:user, :with_multiple_emails).decorate
        email_address = decorated_user.user.reload.email_addresses.last
        email_address.update!(last_sign_in_at: 1.minute.from_now)
        profile_index = AccountShow.new(
          decrypted_pii: {}, personal_key: '', decorated_user: decorated_user,
        )

        expect(profile_index.header_personalization).to eq email_address.email
      end
    end
  end

  describe '#totp_content' do
    context 'user has enabled an authenticator app' do
      it 'returns localization for auth_app_enabled' do
        user = User.new
        allow_any_instance_of(
          TwoFactorAuthentication::AuthAppPolicy,
        ).to receive(:enabled?).and_return(true)

        profile_index = AccountShow.new(
          decrypted_pii: {}, personal_key: '', decorated_user: user.decorate,
        )

        expect(profile_index.totp_content).to eq t('account.index.auth_app_enabled')
      end
    end

    context 'user does not have an authenticator app enabled' do
      it 'returns localization for auth_app_disabled' do
        user = User.new.decorate
        allow_any_instance_of(
          TwoFactorAuthentication::AuthAppPolicy,
        ).to receive(:enabled?).and_return(false)
        profile_index = AccountShow.new(decrypted_pii: {}, personal_key: '', decorated_user: user)

        expect(profile_index.totp_content).to eq t('account.index.auth_app_disabled')
      end
    end
  end

  describe '#backup_codes_generated_at' do
    it 'returns the created_at date of the oldest backup code' do
      user = create(:user)
      create(:backup_code_configuration, created_at: 1.day.ago, user: user)
      oldest_code = create(:backup_code_configuration, created_at: 2.days.ago, user: user)

      account_show = AccountShow.new(
        decrypted_pii: {},
        personal_key: '',
        decorated_user: user.reload.decorate,
      )

      expect(account_show.backup_codes_generated_at).to be_within(
        1.second,
      ).of(
        oldest_code.created_at,
      )
    end

    it 'returns nil if there are not backup codes' do
      user = create(:user)

      account_show = AccountShow.new(
        decrypted_pii: {},
        personal_key: '',
        decorated_user: user.reload.decorate,
      )

      expect(account_show.backup_codes_generated_at).to be_nil
    end
  end
end
