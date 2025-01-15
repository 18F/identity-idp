require 'rails_helper'

RSpec.describe AccountShowPresenter do
  let(:acr_values) { Saml::Idp::Constants::AAL2_AUTHN_CONTEXT_CLASSREF }
  let(:vtr) { nil }
  let(:decrypted_pii) { nil }
  let(:sp_session_request_url) { nil }
  let(:authn_context) do
    AuthnContextResolver.new(
      user:,
      service_provider: nil,
      vtr:,
      acr_values:,
    ).result
  end
  let(:sp_name) { nil }
  let(:user) { build(:user) }
  let(:locked_for_session) { false }

  subject(:presenter) do
    AccountShowPresenter.new(
      decrypted_pii:,
      sp_session_request_url:,
      authn_context:,
      sp_name:,
      user:,
      locked_for_session:,
      change_email_available:,
    )
  end

  describe 'identity_verified_with_facial_match?' do
    subject(:identity_verified_with_facial_match?) do
      presenter.identity_verified_with_facial_match?
    end

    it 'delegates to user' do
      expect(identity_verified_with_facial_match?).to eq(
        user.identity_verified_with_facial_match?,
      )
    end

    context 'using vtr values' do
      let(:acr_values) { nil }
      let(:vtr) { ['C2'] }

      it 'delegates to user' do
        expect(identity_verified_with_facial_match?).to eq(
          user.identity_verified_with_facial_match?,
        )
      end
    end
  end

  describe '#showing_alerts?' do
    subject(:showing_alerts?) { presenter.showing_alerts? }

    it { is_expected.to eq(false) }

    context 'with associated sp' do
      let(:sp_session_request_url) { 'http://example.test' }
      let(:sp_name) { 'Example SP' }

      it { is_expected.to eq(true) }
    end

    context 'with password reset profile' do
      let(:user) { build(:user, :deactivated_password_reset_profile) }

      it { is_expected.to eq(true) }
    end

    context 'using vtr values' do
      let(:acr_values) { nil }
      let(:vtr) { ['C2'] }

      it { is_expected.to eq(false) }

      context 'with associated sp' do
        let(:sp_session_request_url) { 'http://example.test' }
        let(:sp_name) { 'Example SP' }

        it { is_expected.to eq(true) }
      end

      context 'with password reset profile' do
        let(:user) { build(:user, :deactivated_password_reset_profile) }

        it { is_expected.to eq(true) }
      end
    end
  end

  describe '#active_profile?' do
    subject(:active_profile?) { presenter.active_profile? }

    it { is_expected.to eq(false) }

    context 'with proofed user' do
      let(:user) { build(:user, :proofed) }

      it { is_expected.to eq(true) }
    end

    context 'with user who proofed but has pending profile' do
      let(:user) { build(:user, :deactivated_password_reset_profile) }

      it { is_expected.to eq(false) }
    end

    context 'using vtr values' do
      let(:acr_values) { nil }
      let(:vtr) { ['C2'] }

      it { is_expected.to eq(false) }

      context 'with proofed user' do
        let(:user) { build(:user, :proofed) }

        it { is_expected.to eq(true) }
      end

      context 'with user who proofed but has pending profile' do
        let(:user) { build(:user, :deactivated_password_reset_profile) }

        it { is_expected.to eq(false) }
      end
    end
  end

  describe '#active_profile_for_authn_context?' do
    subject(:active_profile_for_authn_context?) { presenter.active_profile_for_authn_context? }

    it { is_expected.to eq(false) }

    context 'with non-facial match proofed user' do
      let(:user) { build(:user, :proofed) }

      it { is_expected.to eq(true) }

      context 'with sp request for non-facial match' do
        let(:acr_values) do
          Saml::Idp::Constants::AAL2_AUTHN_CONTEXT_CLASSREF + ' ' +
            Saml::Idp::Constants::IAL_VERIFIED_ACR
        end

        it { is_expected.to eq(true) }

        context 'with vtr values' do
          let(:vtr) { ['C2.P1'] }

          it { is_expected.to eq(true) }
        end
      end

      context 'with sp request for facial match' do
        let(:acr_values) do
          Saml::Idp::Constants::AAL2_AUTHN_CONTEXT_CLASSREF + ' ' +
            Saml::Idp::Constants::IAL_VERIFIED_FACIAL_MATCH_REQUIRED_ACR
        end

        it { is_expected.to eq(false) }

        context 'with vtr values' do
          let(:acr_values) { nil }
          let(:vtr) { ['C2.Pb'] }

          it { is_expected.to eq(false) }
        end
      end
    end

    context 'with facial match proofed user' do
      let(:user) { build(:user, :proofed_with_selfie) }

      it { is_expected.to eq(true) }

      context 'with sp request for facial match' do
        let(:acr_values) do
          Saml::Idp::Constants::AAL2_AUTHN_CONTEXT_CLASSREF + ' ' +
            Saml::Idp::Constants::IAL_VERIFIED_FACIAL_MATCH_REQUIRED_ACR
        end

        it { is_expected.to eq(true) }

        context 'with acr values' do
          let(:acr_values) { nil }
          let(:vtr) { ['C2.Pb'] }

          it { is_expected.to eq(true) }
        end
      end
    end
  end

  context '#pending_idv?' do
    subject(:pending_idv?) { presenter.pending_idv? }

    it { is_expected.to eq(false) }

    context 'with sp request for non-facial match' do
      let(:acr_values) do
        [
          Saml::Idp::Constants::AAL2_AUTHN_CONTEXT_CLASSREF,
          Saml::Idp::Constants::IAL_VERIFIED_ACR,
        ].join(' ')
      end

      it { is_expected.to eq(true) }

      context 'with non-facial match proofed user' do
        let(:user) { build(:user, :proofed) }

        it { is_expected.to eq(false) }
      end

      context 'with vtr values' do
        let(:acr_values) { nil }
        let(:vtr) { ['C2.P1'] }

        it { is_expected.to eq(true) }

        context 'with non-facial match proofed user' do
          let(:user) { build(:user, :proofed) }

          it { is_expected.to eq(false) }
        end
      end
    end

    context 'with sp request for facial match' do
      let(:acr_values) do
        Saml::Idp::Constants::AAL2_AUTHN_CONTEXT_CLASSREF + ' ' +
          Saml::Idp::Constants::IAL_VERIFIED_FACIAL_MATCH_REQUIRED_ACR
      end

      it { is_expected.to eq(true) }

      context 'with non-facial match proofed user' do
        let(:user) { build(:user, :proofed) }

        it { is_expected.to eq(true) }
      end

      context 'with facial match proofed user' do
        let(:user) { build(:user, :proofed_with_selfie) }

        it { is_expected.to eq(false) }
      end

      context 'with vtr values' do
        let(:acr_values) { nil }
        let(:vtr) { ['C2.Pb'] }

        it { is_expected.to eq(true) }

        context 'with non-facial match proofed user' do
          let(:user) { build(:user, :proofed) }

          it { is_expected.to eq(true) }
        end

        context 'with facial match proofed user' do
          let(:user) { build(:user, :proofed_with_selfie) }

          it { is_expected.to eq(false) }
        end
      end
    end
  end

  context '#pending_ipp?' do
    subject(:pending_ipp?) { presenter.pending_ipp? }

    it { is_expected.to eq(false) }

    context 'with user pending ipp verification' do
      let(:user) { build(:user, :with_pending_in_person_enrollment) }

      it { is_expected.to eq(true) }
    end

    context 'when current user has ipp pending profile deactivated for password reset' do
      let(:user) { create(:user, :with_pending_in_person_enrollment) }

      before do
        user.profiles.first.update!(deactivation_reason: :password_reset)
      end

      it 'is expected to return false' do
        account_show = AccountShowPresenter.new(
          decrypted_pii: {},
          sp_session_request_url: nil,
          authn_context: nil,
          sp_name: nil,
          user: user,
          locked_for_session: false,
          change_email_available: false,
        )

        expect(account_show.pending_ipp?).to be(false)
      end
    end
  end

  context '#pending_gpo?' do
    subject(:pending_gpo?) { presenter.pending_gpo? }

    it { is_expected.to eq(false) }

    context 'with user pending gpo verification' do
      let(:user) { create(:user, :with_pending_gpo_profile) }

      it { is_expected.to eq(true) }
    end

    context 'when current user has gpo pending profile deactivated for password reset' do
      let(:user) { create(:user, :with_pending_gpo_profile) }

      before do
        user.profiles.first.update!(deactivation_reason: :password_reset)
      end

      it 'is expected to return false' do
        account_show = AccountShowPresenter.new(
          decrypted_pii: {},
          sp_session_request_url: nil,
          authn_context: nil,
          sp_name: nil,
          user: user,
          locked_for_session: false,
          change_email_available: false,
        )

        expect(account_show.pending_ipp?).to be(false)
      end
    end
  end

  context '#show_idv_partial?' do
    subject(:show_idv_partial?) { presenter.show_idv_partial? }

    it { is_expected.to eq(false) }

    context 'with proofed user' do
      let(:user) { build(:user, :proofed) }

      it { is_expected.to eq(true) }
    end

    context 'with pending idv' do
      let(:user) { build(:user, :proofed) }
      let(:acr_values) do
        Saml::Idp::Constants::AAL2_AUTHN_CONTEXT_CLASSREF + ' ' +
          Saml::Idp::Constants::IAL_VERIFIED_FACIAL_MATCH_REQUIRED_ACR
      end

      it { is_expected.to eq(true) }

      context 'with vtr values' do
        let(:acr_values) { nil }
        let(:vtr) { ['C2.Pb'] }

        it { is_expected.to eq(true) }
      end
    end

    context 'with user pending ipp verification' do
      let(:user) { build(:user, :with_pending_in_person_enrollment) }

      it { is_expected.to eq(true) }
    end

    context 'with user pending gpo verification' do
      let(:user) { create(:user, :with_pending_gpo_profile) }

      it { is_expected.to eq(true) }
    end
  end

  describe '#formatted_ipp_due_date' do
    let(:user) { build(:user, :with_pending_in_person_enrollment) }

    subject(:formatted_ipp_due_date) { presenter.formatted_ipp_due_date }

    it 'formats a date string' do
      expect { Date.parse(formatted_ipp_due_date) }.not_to raise_error
    end
  end

  describe '#formatted_legacy_idv_date' do
    let(:user) { build(:user, :proofed_with_selfie) }

    subject(:formatted_legacy_idv_date) { presenter.formatted_legacy_idv_date }

    it 'formats a date string' do
      expect { Date.parse(formatted_legacy_idv_date) }.not_to raise_error
    end
  end

  describe '#connected_to_initiating_idv_sp?' do
    let(:initiating_service_provider) { build(:service_provider) }
    let(:user) { create(:user, identities: [identity].compact, profiles: [profile].compact) }
    let(:profile) do
      build(:profile, :active, initiating_service_provider:)
    end
    let(:last_ial2_authenticated_at) { 2.days.ago }
    let(:identity) do
      build(
        :service_provider_identity,
        service_provider: initiating_service_provider.issuer,
        last_ial2_authenticated_at:,
      )
    end

    subject(:connected_to_initiating_idv_sp?) { presenter.connected_to_initiating_idv_sp? }

    context 'the user verified without an initiating service provider' do
      let(:initiating_service_provider) { nil }
      let(:identity) { nil }

      it { expect(connected_to_initiating_idv_sp?).to eq(false) }
    end

    context 'the user does not have an identity for the initiating service provider' do
      let(:identity) { nil }

      it { expect(connected_to_initiating_idv_sp?).to eq(false) }
    end

    context 'the user has signed in to the initiating service provider' do
      it { expect(connected_to_initiating_idv_sp?).to eq(true) }
    end

    context 'the user has not signed in to the initiating service provider' do
      let(:last_ial2_authenticated_at) { nil }

      it { expect(connected_to_initiating_idv_sp?).to eq(false) }
    end
  end

  describe '#header_personalization' do
    context 'AccountShowPresenter instance has decrypted_pii' do
      it "returns the user's first name" do
        user = User.new
        first_name = 'John'
        last_name = 'Doe'
        birthday = Date.new(2000, 7, 27)
        decrypted_pii = Pii::Attributes.new_from_hash(
          first_name: first_name, last_name: last_name,
          dob: birthday
        )
        profile_index = AccountShowPresenter.new(
          decrypted_pii: decrypted_pii,
          user: user,
          sp_session_request_url: nil,
          authn_context: nil,
          sp_name: nil,
          locked_for_session: false,
          change_email_available: false,
        )

        expect(profile_index.header_personalization).to eq first_name
      end
    end

    context 'AccountShowPresenter instance does not have decrypted_pii' do
      it 'returns the email the user used to sign in last' do
        user = create(:user, :with_multiple_emails)
        email_address = user.reload.email_addresses.last
        email_address.update!(last_sign_in_at: 1.minute.from_now)
        profile_index = AccountShowPresenter.new(
          decrypted_pii: {},
          user: user,
          sp_session_request_url: nil,
          authn_context: nil,
          sp_name: nil,
          locked_for_session: false,
          change_email_available: false,
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
          user: user,
          sp_session_request_url: nil,
          authn_context: nil,
          sp_name: nil,
          locked_for_session: false,
          change_email_available: false,
        )

        expect(profile_index.totp_content).to eq t('account.index.auth_app_enabled')
      end
    end

    context 'user does not have an authenticator app enabled' do
      it 'returns localization for auth_app_disabled' do
        user = User.new
        allow_any_instance_of(
          TwoFactorAuthentication::AuthAppPolicy,
        ).to receive(:enabled?).and_return(false)
        profile_index = AccountShowPresenter.new(
          decrypted_pii: {},
          user: user,
          sp_session_request_url: nil,
          authn_context: nil,
          sp_name: nil,
          locked_for_session: false,
          change_email_available: false,
        )

        expect(profile_index.totp_content).to eq t('account.index.auth_app_disabled')
      end
    end
  end

  describe '#connected_apps' do
    let(:user) { create(:user, identities: [create(:service_provider_identity)]) }

    subject(:connected_apps) { presenter.connected_apps }

    it 'delegates to user, eager-loading view-specific relations' do
      expect(connected_apps).to be_present
        .and eq(user.connected_apps)
        .and all(
          satisfy do |app|
            app.association(:service_provider_record).loaded? &&
              app.association(:email_address).loaded?
          end,
        )
    end
  end

  describe '#backup_codes_generated_at' do
    it 'returns the created_at date of the oldest backup code' do
      user = create(:user)
      create(:backup_code_configuration, created_at: 1.day.ago, user: user)
      oldest_code = create(:backup_code_configuration, created_at: 2.days.ago, user: user)

      account_show = AccountShowPresenter.new(
        decrypted_pii: {},
        sp_session_request_url: nil,
        authn_context: nil,
        sp_name: nil,
        user: user.reload,
        locked_for_session: false,
        change_email_available: false,
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
        sp_session_request_url: nil,
        authn_context: nil,
        sp_name: nil,
        user: user.reload,
        locked_for_session: false,
        change_email_available: false,
      )

      expect(account_show.backup_codes_generated_at).to be_nil
    end
  end

  describe '#pii' do
    let(:user) { build(:user, :proofed) }
    let(:dob) { nil }
    let(:decrypted_pii) { Pii::Attributes.new_from_hash(dob:) }

    subject(:pii) { presenter.pii }

    context 'birthday is formatted as an american date' do
      let(:dob) { '12/31/1970' }

      it 'parses the birthday' do
        expect(pii.dob).to eq('December 31, 1970')
      end
    end

    context 'birthday is formatted as an international date' do
      let(:dob) { '1970-01-01' }

      it 'parses the birthday' do
        expect(pii.dob).to eq('January 01, 1970')
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
          user: user,
          sp_session_request_url: nil,
          authn_context: nil,
          sp_name: nil,
          locked_for_session: false,
          change_email_available: false,
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
          user: user,
          sp_session_request_url: nil,
          authn_context: nil,
          sp_name: nil,
          locked_for_session: false,
          change_email_available: false,
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
          user: user,
          sp_session_request_url: nil,
          authn_context: nil,
          sp_name: nil,
          locked_for_session: false,
          change_email_available: false,
        )

        expect(profile_index.personal_key_generated_at).to be_nil
      end
    end
  end
end
