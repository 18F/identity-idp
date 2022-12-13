require 'rails_helper'

describe AccountShowPresenter do
  describe '#header_personalization' do
    context 'AccountShowPresenter instance has decrypted_pii' do
      it "returns the user's first name" do
        user = User.new
        first_name = 'John'
        last_name = 'Doe'
        birthday = Date.new(2000, 7, 27)
        decrypted_pii = Pii::Attributes.new_from_hash(
          first_name: first_name,
          last_name: last_name,
          dob: birthday,
        )
        profile_index = AccountShowPresenter.new(
          decrypted_pii: decrypted_pii,
          personal_key: '',
          decorated_user: user.decorate,
          sp_session_request_url: nil,
          sp_name: nil,
          locked_for_session: false,
        )

        expect(profile_index.header_personalization).to eq first_name
      end
    end

    context 'AccountShowPresenter instance does not have decrypted_pii' do
      it 'returns the email the user used to sign in last' do
        decorated_user = create(:user, :with_multiple_emails).decorate
        email_address = decorated_user.user.reload.email_addresses.last
        email_address.update!(last_sign_in_at: 1.minute.from_now)
        profile_index = AccountShowPresenter.new(
          decrypted_pii: {},
          personal_key: '',
          decorated_user: decorated_user,
          sp_session_request_url: nil,
          sp_name: nil,
          locked_for_session: false,
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

        profile_index = AccountShowPresenter.new(
          decrypted_pii: {},
          personal_key: '',
          decorated_user: user.decorate,
          sp_session_request_url: nil,
          sp_name: nil,
          locked_for_session: false,
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
        profile_index = AccountShowPresenter.new(
          decrypted_pii: {},
          personal_key: '',
          decorated_user: user,
          sp_session_request_url: nil,
          sp_name: nil,
          locked_for_session: false,
        )

        expect(profile_index.totp_content).to eq t('account.index.auth_app_disabled')
      end
    end
  end

  describe '#backup_codes_generated_at' do
    it 'returns the created_at date of the oldest backup code' do
      user = create(:user)
      create(:backup_code_configuration, created_at: 1.day.ago, user: user)
      oldest_code = create(:backup_code_configuration, created_at: 2.days.ago, user: user)

      account_show = AccountShowPresenter.new(
        decrypted_pii: {},
        personal_key: '',
        sp_session_request_url: nil,
        sp_name: nil,
        decorated_user: user.reload.decorate,
        locked_for_session: false,
      )

      expect(account_show.backup_codes_generated_at).to be_within(
        1.second,
      ).of(
        oldest_code.created_at,
      )
    end

    it 'returns nil if there are not backup codes' do
      user = create(:user)

      account_show = AccountShowPresenter.new(
        decrypted_pii: {},
        personal_key: '',
        sp_session_request_url: nil,
        sp_name: nil,
        decorated_user: user.reload.decorate,
        locked_for_session: false,
      )

      expect(account_show.backup_codes_generated_at).to be_nil
    end
  end

  describe '#pii' do
    let(:user) { build(:user) }
    let(:decrypted_pii) do
      Pii::Attributes.new_from_hash(dob: dob)
    end

    subject(:account_show) do
      AccountShowPresenter.new(
        decrypted_pii: decrypted_pii,
        personal_key: '',
        sp_session_request_url: nil,
        sp_name: nil,
        decorated_user: user.decorate,
        locked_for_session: false,
      )
    end

    context 'birthday is formatted as an american date' do
      let(:dob) { '12/31/1970' }

      it 'parses the birthday' do
        expect(account_show.pii.dob).to eq('December 31, 1970')
      end
    end

    context 'birthday is formatted as an international date' do
      let(:dob) { '1970-01-01' }

      it 'parses the birthday' do
        expect(account_show.pii.dob).to eq('January 01, 1970')
      end
    end
  end

  describe '#personal_key_generated_at' do
    context 'the user has a encrypted_recovery_code_digest_generated_at date' do
      it 'returns the date in the digest' do
        digest_generated_at = 1.day.ago
        profile = create(
          :profile,
          :active,
          :verified,
          user: create(:user, encrypted_recovery_code_digest_generated_at: digest_generated_at),
        )
        user = profile.user
        profile_index = AccountShowPresenter.new(
          decrypted_pii: {},
          personal_key: '',
          decorated_user: user.decorate,
          sp_session_request_url: nil,
          sp_name: nil,
          locked_for_session: false,
        )

        expect(
          profile_index.personal_key_generated_at,
        ).to be_within(1.second).of(digest_generated_at)
      end
    end

    context 'the user does not have a encrypted_recovery_code_digest_generated_at but is proofed' do
      it 'returns the date the user was proofed' do
        profile = create(
          :profile,
          :active,
          :verified,
          user: create(:user),
        )
        user = profile.user
        profile_index = AccountShowPresenter.new(
          decrypted_pii: {},
          personal_key: '',
          decorated_user: user.decorate,
          sp_session_request_url: nil,
          sp_name: nil,
          locked_for_session: false,
        )

        expect(
          profile_index.personal_key_generated_at,
        ).to be_within(1.second).of(profile.verified_at)
      end
    end

    context 'the user has no encrypted_recovery_code_digest_generated_at and is not proofed' do
      it 'returns nil' do
        user = create(:user)

        profile_index = AccountShowPresenter.new(
          decrypted_pii: {},
          personal_key: '',
          decorated_user: user.decorate,
          sp_session_request_url: nil,
          sp_name: nil,
          locked_for_session: false,
        )

        expect(profile_index.personal_key_generated_at).to be_nil
      end
    end
  end
end
