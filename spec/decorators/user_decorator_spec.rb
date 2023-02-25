require 'rails_helper'

describe UserDecorator do
  describe '#visible_email_addresses' do
    let(:user) { create(:user) }
    let(:confirmed_email_address) { user.email_addresses.detect(&:confirmed?) }
    let!(:unconfirmed_expired_email_address) do
      create(
        :email_address,
        user: user,
        confirmed_at: nil,
        confirmation_sent_at: 36.hours.ago,
      )
    end
    let!(:unconfirmed_unexpired_email_address) do
      create(
        :email_address,
        user: user,
        confirmed_at: nil,
        confirmation_sent_at: 5.minutes.ago,
      )
    end

    subject { described_class.new(user.reload) }

    it 'shows email addresses that have been confirmed' do
      expect(subject.visible_email_addresses).to include(confirmed_email_address)
    end

    it 'hides emails address that are unconfirmed and expired' do
      expect(subject.visible_email_addresses).to_not include(unconfirmed_expired_email_address)
    end

    it 'shows emails that are not confirmed and not expired' do
      expect(subject.visible_email_addresses).to include(unconfirmed_unexpired_email_address)
    end
  end

  describe '#email_language_preference_description' do
    let(:user) { build_stubbed(:user, email_language: email_language) }

    subject(:description) { UserDecorator.new(user).email_language_preference_description }

    context 'when the user has a supported email_language' do
      let(:email_language) { 'es' }

      it 'is the that language' do
        expect(description).to eq(I18n.t('account.email_language.name.es'))
      end
    end

    context 'when the user has a nil email_language' do
      let(:email_language) { nil }

      it 'is the default language' do
        expect(description).to eq(I18n.t('account.email_language.name.en'))
      end
    end

    context 'when the user has an unsupported email_language' do
      let(:email_language) { 'zz' }

      it 'is the default language' do
        expect(description).to eq(I18n.t('account.email_language.name.en'))
      end
    end
  end

  describe '#lockout_time_expiration' do
    it 'returns the time at which lockout will expire' do
      freeze_time do
        user = build_stubbed(:user, second_factor_locked_at: Time.zone.now - 180)
        user_decorator = UserDecorator.new(user)
        allow(IdentityConfig.store).to receive(:lockout_period_in_minutes).and_return(8)

        expect(user_decorator.lockout_time_expiration).to eq Time.zone.now + 300
      end
    end
  end

  describe '#active_identity_for' do
    it 'returns Identity matching ServiceProvider' do
      sp = create(:service_provider, issuer: 'http://sp.example.com')
      user = create(:user)
      user.identities << create(
        :service_provider_identity,
        service_provider: sp.issuer,
        session_uuid: SecureRandom.uuid,
      )

      user_decorator = UserDecorator.new(user)

      expect(user_decorator.active_identity_for(sp)).to eq user.last_identity
    end
  end

  describe '#pending_profile_requires_verification?' do
    it 'returns false when no pending profile exists' do
      user = User.new
      user_decorator = UserDecorator.new(user)
      allow(user_decorator).to receive(:pending_profile).and_return(nil)

      expect(user_decorator.pending_profile_requires_verification?).to eq false
    end

    it 'returns true when pending profile exists and identity is not verified' do
      user = User.new
      user_decorator = UserDecorator.new(user)
      allow(user_decorator).to receive(:pending_profile).and_return('profile')
      allow(user_decorator).to receive(:identity_not_verified?).and_return(true)

      expect(user_decorator.pending_profile_requires_verification?).to eq true
    end

    it 'returns false when active profile is newer than pending profile' do
      user = User.new
      user_decorator = UserDecorator.new(user)
      allow(user_decorator).to receive(:pending_profile).and_return('profile')
      allow(user_decorator).to receive(:identity_not_verified?).and_return(false)
      allow(user_decorator).to receive(:active_profile_newer_than_pending_profile?).
        and_return(true)

      expect(user_decorator.pending_profile_requires_verification?).to eq false
    end

    it 'returns true when pending profile is newer than active profile' do
      user = User.new
      user_decorator = UserDecorator.new(user)
      allow(user_decorator).to receive(:pending_profile).and_return('profile')
      allow(user_decorator).to receive(:identity_not_verified?).and_return(false)
      allow(user_decorator).to receive(:active_profile_newer_than_pending_profile?).
        and_return(false)

      expect(user_decorator.pending_profile_requires_verification?).to eq true
    end
  end

  describe '#identity_not_verified?' do
    it 'returns true if identity_verified returns false' do
      user = User.new
      user_decorator = UserDecorator.new(user)
      allow(user_decorator).to receive(:identity_verified?).and_return(false)

      expect(user_decorator.identity_not_verified?).to eq true
    end

    it 'returns false if identity_verified returns true' do
      user = User.new
      user_decorator = UserDecorator.new(user)
      allow(user_decorator).to receive(:identity_verified?).and_return(true)

      expect(user_decorator.identity_not_verified?).to eq false
    end
  end

  describe '#identity_verified?' do
    it 'returns true if user has an active profile' do
      user = User.new
      user_decorator = UserDecorator.new(user)
      allow(user).to receive(:active_profile).and_return(Profile.new)

      expect(user_decorator.identity_verified?).to eq true
    end

    it 'returns false if user does not have an active profile' do
      user = User.new
      user_decorator = UserDecorator.new(user)
      allow(user).to receive(:active_profile).and_return(nil)

      expect(user_decorator.identity_verified?).to eq false
    end
  end

  describe '#active_profile_newer_than_pending_profile?' do
    it 'returns true if the active profile is newer than the pending profile' do
      user = User.new
      user_decorator = UserDecorator.new(user)
      allow(user).to receive(:active_profile).and_return(Profile.new(activated_at: Time.zone.now))
      allow(user_decorator).to receive(:pending_profile).
        and_return(Profile.new(created_at: 1.day.ago))

      expect(user_decorator.active_profile_newer_than_pending_profile?).to eq true
    end

    it 'returns false if the active profile is older than the pending profile' do
      user = User.new
      user_decorator = UserDecorator.new(user)
      allow(user).to receive(:active_profile).and_return(Profile.new(activated_at: 1.day.ago))
      allow(user_decorator).to receive(:pending_profile).
        and_return(Profile.new(created_at: Time.zone.now))

      expect(user_decorator.active_profile_newer_than_pending_profile?).to eq false
    end
  end

  describe '#locked_out?' do
    let(:locked_at) { nil }
    let(:user) { User.new }

    before { allow(user).to receive(:second_factor_locked_at).and_return(locked_at) }

    around do |ex|
      freeze_time { ex.run }
    end

    subject(:locked_out?) { UserDecorator.new(user).locked_out? }

    it { expect(locked_out?).to eq(false) }

    context 'second factor locked out recently' do
      let(:locked_at) { Time.zone.now }

      it { expect(locked_out?).to eq(true) }
    end

    context 'second factor locked out a while ago' do
      let(:locked_at) { IdentityConfig.store.lockout_period_in_minutes.minutes.ago - 1.second }

      it { expect(locked_out?).to eq(false) }
    end
  end

  describe '#no_longer_locked_out?' do
    let(:locked_at) { nil }
    let(:user) { User.new }

    before { allow(user).to receive(:second_factor_locked_at).and_return(locked_at) }

    around do |ex|
      freeze_time { ex.run }
    end

    subject(:no_longer_locked_out?) { UserDecorator.new(user).no_longer_locked_out? }

    it { expect(no_longer_locked_out?).to eq(false) }

    context 'second factor locked out recently' do
      let(:locked_at) { Time.zone.now }

      it { expect(no_longer_locked_out?).to eq(false) }
    end

    context 'second factor locked out a while ago' do
      let(:locked_at) { IdentityConfig.store.lockout_period_in_minutes.minutes.ago - 1.second }

      it { expect(no_longer_locked_out?).to eq(true) }
    end
  end

  describe '#recent_events' do
    let!(:user) { create(:user, :signed_up, created_at: Time.zone.now - 100.days) }
    let(:decorated_user) { user.decorate }
    let!(:event) { create(:event, user: user, created_at: Time.zone.now - 98.days) }
    let!(:identity) do
      create(
        :service_provider_identity,
        :active,
        user: user,
        last_authenticated_at: Time.zone.now - 60.days,
      )
    end
    let!(:another_event) do
      create(:event, user: user, event_type: :email_changed, created_at: Time.zone.now - 30.days)
    end

    it 'interleaves identities and events, decorates events, and sorts them in descending order' do
      expect(decorated_user.recent_events).
        to eq [another_event.decorate, identity, event.decorate]
    end
  end

  describe '#password_reset_profile' do
    let(:user) { create(:user) }
    subject(:decorated_user) { UserDecorator.new(user) }

    context 'with no profiles' do
      it { expect(decorated_user.password_reset_profile).to be_nil }
    end

    context 'with an active profile' do
      let(:active_profile) do
        build(:profile, :active, :verified, activated_at: 1.day.ago, pii: { first_name: 'Jane' })
      end

      before do
        user.profiles << [
          active_profile,
          build(:profile, :verified, activated_at: 5.days.ago, pii: { first_name: 'Susan' }),
        ]
      end

      it { expect(decorated_user.password_reset_profile).to be_nil }

      context 'when the active profile is deactivated due to password reset' do
        before { active_profile.deactivate(:password_reset) }

        it { expect(decorated_user.password_reset_profile).to eq(active_profile) }

        context 'with a previously-cancelled pending profile' do
          before do
            user.profiles << build(:profile, :verification_cancelled)
          end

          it { expect(decorated_user.password_reset_profile).to eq(active_profile) }
        end
      end
    end
  end

  describe '#threatmetrix_review_pending_profile' do
    let(:user) { create(:user) }
    subject(:decorated_user) { UserDecorator.new(user) }

    context 'with a threatmetrix review pending profile' do
      it 'returns the profile' do
        profile = create(
          :profile, user: user, active: false, deactivation_reason: :threatmetrix_review_pending
        )

        expect(decorated_user.threatmetrix_review_pending_profile).to eq(profile)
      end
    end

    context 'without a threatmetrix review pending profile' do
      it { expect(decorated_user.threatmetrix_review_pending_profile).to eq(nil) }
    end
  end

  describe '#delete_account_bullet_key' do
    let(:user_decorator) { UserDecorator.new(build_stubbed(:user)) }

    it 'returns ial1 if identity is not verified' do
      allow(user_decorator).to receive(:identity_verified?).and_return(false)
      expect(user_decorator.delete_account_bullet_key).
        to eq t('users.delete.bullet_2_basic', app_name: APP_NAME)
    end

    it 'returns ial2 if identity is verified' do
      allow(user_decorator).to receive(:identity_verified?).and_return(true)
      expect(user_decorator.delete_account_bullet_key).
        to eq t('users.delete.bullet_2_verified', app_name: APP_NAME)
    end
  end

  describe '#connected_apps' do
    let(:user) { create(:user) }
    let(:app) { create(:service_provider_identity, service_provider: 'aaa') }
    let(:deleted_app) do
      create(:service_provider_identity, service_provider: 'bbb', deleted_at: 5.days.ago)
    end

    let(:user_decorator) { user.decorate }

    before { user.identities << app << deleted_app }

    it 'omits deleted apps' do
      expect(user_decorator.connected_apps).to eq([app])
    end
  end

  describe '#second_last_signed_in_at' do
    it 'returns second most recent full authentication event' do
      user = create(:user)
      _event1 = create(:event, user: user, event_type: 'sign_in_after_2fa')
      event2 = create(:event, user: user, event_type: 'sign_in_after_2fa')
      _event3 = create(:event, user: user, event_type: 'sign_in_after_2fa')

      expect(user.decorate.second_last_signed_in_at).to eq(event2.reload.created_at)
    end
  end

  describe '#reproof_for_irs?' do
    let(:service_provider) { create(:service_provider) }

    it 'returns false if the service provider is not an attempts API service provider' do
      user = create(:user, :proofed)

      expect(user.decorate.reproof_for_irs?(service_provider: service_provider)).to be_falsy
    end

    context 'an attempts API service provider' do
      let(:service_provider) { create(:service_provider, :irs) }

      it 'returns false if the user has not proofed before' do
        user = create(:user)

        expect(user.decorate.reproof_for_irs?(service_provider: service_provider)).to be_falsy
      end

      it 'returns false if the active profile initiating SP was an attempts API SP' do
        user = create(:user, :proofed)

        user.active_profile.update!(initiating_service_provider: service_provider)

        expect(user.decorate.reproof_for_irs?(service_provider: service_provider)).to be_falsy
      end

      it 'returns true if the active profile initiating SP was not an attempts API SP' do
        user = create(:user, :proofed)

        expect(user.decorate.reproof_for_irs?(service_provider: service_provider)).to be_truthy
      end
    end
  end
end
