require 'rails_helper'

RSpec.describe TokenExchangeGrant do
  let(:user) { create(:user, :fully_registered) }
  let(:service_provider) { create(:service_provider, :delegation_service_provider) }
  let(:application) { create(:service_provider, :delegation_application) }
  let(:other_application) { create(:service_provider, :delegation_application) }

  before { allow(IdentityConfig.store).to receive(:token_exchange_enabled).and_return(true) }

  def approve(remember: true, **options)
    described_class.approve!(
      user:, service_provider:, application:, source: 'consent_screen', remember:, **options,
    )
  end

  describe '.approve!' do
    it 'records one remembered approval with the content versions the person saw' do
      application.agency.update!(consent_content_version: 3, consent_material_version: 2)
      application.update!(consent_content_version: 5, consent_material_version: 4)
      service_provider.update!(sp_content_version: 7)

      grant = approve

      expect(grant.service_provider_issuer).to eq(service_provider.issuer)
      expect(grant.application).to eq(application)
      expect(grant.delegation_id).to start_with('dlg_')
      expect(grant.remember_until).to be_within(1.minute).of(described_class::MAX_REMEMBER.from_now)
      expect(grant.rails_session_id).to be_nil
      expect(grant.agency_content_version).to eq(3)
      expect(grant.application_content_version).to eq(5)
      expect(grant.sp_content_version).to eq(7)
    end

    it 'records a single-authorization approval with the session it was given in' do
      grant = approve(remember: false, rails_session_id: 'session-1')

      expect(grant.remember_until).to be_nil
      expect(grant.rails_session_id).to eq('session-1')
    end

    it 'supersedes the earlier live row for the same key, keeping it for the record' do
      first = approve
      second = approve

      expect(first.reload.revoked_at).to be_present
      expect(first.revocation_reason).to eq('superseded_by_new_consent')
      expect(described_class.live.where(user:, application:)).to eq([second])
    end

    it 'does not touch approvals for other applications' do
      other_grant = described_class.approve!(
        user:, service_provider:, application: other_application,
        source: 'account_page', remember: true
      )
      approve

      expect(other_grant.reload.revoked_at).to be_nil
    end
  end

  describe '#service_provider_record' do
    it 'is the service provider the approval names, by issuer' do
      grant = approve
      grant.reload

      expect(grant.service_provider_record).to eq(service_provider)
    end

    it 'is nil when the service provider has left the registry' do
      grant = approve
      service_provider.destroy!
      grant.reload

      expect(grant.service_provider_record).to be_nil
      expect(grant.valid_now?).to eq(false)
    end
  end

  describe '.authorizes?' do
    it 'is true only for a live, current approval of exactly that application' do
      approve

      expect(
        described_class.authorizes?(
          user:, service_provider_issuer: service_provider.issuer, application:,
        ),
      ).to eq(true)
      expect(
        described_class.authorizes?(
          user:, service_provider_issuer: service_provider.issuer, application: other_application,
        ),
      ).to eq(false)
      expect(
        described_class.authorizes?(
          user:, service_provider_issuer: 'urn:someone-else', application:,
        ),
      ).to eq(false)
    end

    it 'is false once the approval is revoked or the remember period has passed' do
      grant = approve

      travel_to(described_class::MAX_REMEMBER.from_now + 1.day) do
        expect(grant.valid_now?).to eq(false)
      end

      grant.revoke!(reason: 'user_revoked')
      expect(
        described_class.authorizes?(
          user:, service_provider_issuer: service_provider.issuer, application:,
        ),
      ).to eq(false)
    end
  end

  describe '#valid_now?' do
    it 'is false after a material content change by the application, its agency or the SP' do
      grant = approve
      expect(grant.valid_now?).to eq(true)

      # An editorial edit bumps only the content version and does not re-ask.
      application.update!(consent_content_version: 2)
      expect(grant.reload.valid_now?).to eq(true)

      # A material edit moves the material version past the version the person saw.
      application.update!(consent_content_version: 3, consent_material_version: 3)
      expect(grant.reload.valid_now?).to eq(false)

      grant = approve
      application.agency.update!(consent_content_version: 2, consent_material_version: 2)
      expect(grant.reload.valid_now?).to eq(false)

      grant = approve
      service_provider.update!(sp_content_version: 2, sp_material_version: 2)
      expect(grant.reload.valid_now?).to eq(false)
    end

    it 'is false when the application or the service provider is no longer active or approved' do
      grant = approve
      application.update!(active: false)
      expect(grant.reload.valid_now?).to eq(false)

      application.update!(active: true)
      service_provider.update!(token_exchange_enabled_sp: false)
      expect(grant.reload.valid_now?).to eq(false)
    end

    context 'for a single-authorization approval' do
      let!(:identity) do
        create(
          :service_provider_identity, user:, service_provider: service_provider.issuer,
                                      rails_session_id: 'session-1'
        )
      end

      it 'is valid only while the service provider identity is still in that browser session' do
        grant = approve(remember: false, rails_session_id: 'session-1')
        expect(grant.valid_now?).to eq(true)

        identity.update!(rails_session_id: 'session-2')
        expect(grant.reload.valid_now?).to eq(false)
      end

      it 'lets the caller assert the current authorization from context' do
        grant = approve(remember: false, rails_session_id: 'session-1')
        identity.update!(rails_session_id: 'session-2')

        expect(grant.valid_now?(current_authorization: true)).to eq(true)
        expect(grant.valid_now?(current_authorization: false)).to eq(false)
      end

      it 'reads the browser session from an identity the caller already holds' do
        grant = approve(remember: false, rails_session_id: 'session-1')
        loaded = ServiceProviderIdentity.find(identity.id)
        identity.update!(rails_session_id: 'session-2')

        expect(grant.valid_now?(identity: loaded)).to eq(true)
        expect(grant.valid_now?).to eq(false)
      end
    end
  end

  describe '.live_by_application' do
    it 'returns the live approvals keyed by application id, bound to the given records' do
      kept = approve
      described_class.approve!(
        user:, service_provider:, application: other_application,
        source: 'account_page', remember: true
      ).revoke!(reason: 'user_revoked')

      grants = described_class.live_by_application(
        user:, service_provider_issuer: service_provider.issuer,
        applications: [application, other_application]
      )

      expect(grants.keys).to eq([application.id])
      expect(grants[application.id]).to eq(kept)
      expect(grants[application.id].application).to equal(application)
    end

    it 'is empty with no applications and runs no query' do
      expect(
        described_class.live_by_application(
          user:, service_provider_issuer: service_provider.issuer, applications: [],
        ),
      ).to eq({})
    end
  end

  describe '.partition_current' do
    it 'keeps remembered, current approvals and lists every other application for approval' do
      third_application = create(:service_provider, :delegation_application)
      kept = approve
      single_use = described_class.approve!(
        user:, service_provider:, application: other_application,
        source: 'consent_screen', remember: false, rails_session_id: 'session-1'
      )

      partition = described_class.partition_current(
        user:, service_provider_issuer: service_provider.issuer,
        applications: [third_application, other_application, application]
      )

      expect(partition[:kept]).to eq([kept])
      expect(partition[:needing_approval]).to eq([third_application, other_application])
      expect(single_use.reload).not_to be_revoked
    end

    it 'lists an application whose agency content changed materially since the approval' do
      approve
      application.agency.update!(consent_content_version: 2, consent_material_version: 2)

      partition = described_class.partition_current(
        user:, service_provider_issuer: service_provider.issuer, applications: [application],
      )

      expect(partition[:kept]).to be_empty
      expect(partition[:needing_approval]).to eq([application])
      expect(application.association(:agency)).to be_loaded
    end
  end

  describe '.revoke_for! and .revoke_all_for!' do
    it 'revokes one application, or every approval given to a service provider' do
      approve
      described_class.approve!(
        user:, service_provider:, application: other_application,
        source: 'account_page', remember: true
      )

      described_class.revoke_for!(
        user:, service_provider_issuer: service_provider.issuer, application:,
        reason: 'user_revoked'
      )
      expect(described_class.live.where(user:).map(&:application)).to eq([other_application])

      described_class.revoke_all_for!(
        user:, service_provider_issuer: service_provider.issuer, reason: 'sp_disconnected',
      )
      expect(described_class.live.where(user:)).to be_empty
      expect(described_class.where(user:).count).to eq(2)
    end
  end

  describe '#revoke!' do
    it 'tells the application agency, with the reason' do
      grant = approve
      expect(DelegatedAccessEvents).to receive(:access_revoked)
        .with(grant:, reason: 'sp_disconnected')

      grant.revoke!(reason: 'sp_disconnected')
    end

    it 'ends every live delegated token and refresh token issued under the approval' do
      grant = approve
      plaintext = TokenExchangeToken.generate_token
      issued = create(:token_exchange_token, grant:, plaintext:)
      refresh = create(:token_exchange_refresh_token, token_exchange_token: issued)
      already_ended = create(:token_exchange_token, :revoked, grant:)
      expect(DelegatedTokenStore.read(plaintext)).to be_present

      freeze_time do
        grant.revoke!(reason: 'user_revoked')

        expect(DelegatedTokenStore.read(plaintext)).to be_nil
        expect(issued.reload.revoked_at).to eq(Time.zone.now)
        expect(issued.revocation_reason).to eq('user_revoked')
        expect(refresh.reload.revoked_at).to eq(Time.zone.now)
        expect(refresh.revocation_reason).to eq('user_revoked')
        expect(already_ended.reload.revocation_reason).to eq('user_revoked')
      end
    end
  end

  describe '.revoke_all_for_user!' do
    it 'ends every live approval of the person, with their tokens and families, nobody else\'s' do
      grant = approve
      other_application = create(:service_provider, :delegation_application)
      other_grant = approve(application: other_application)
      issued = create(:token_exchange_token, grant:)
      refresh = create(:token_exchange_refresh_token, token_exchange_token: issued)
      someone_else = create(:token_exchange_grant)

      described_class.revoke_all_for_user!(user:, reason: 'account_suspended')

      [grant, other_grant, issued, refresh].each do |row|
        expect(row.reload.revocation_reason).to eq('account_suspended')
      end
      expect(someone_else.reload.revoked_at).to be_nil
    end
  end

  describe 're-approval' do
    it 'keeps delegated tokens working and re-points them at the replacement approval' do
      earlier = approve
      plaintext = TokenExchangeToken.generate_token
      issued = create(:token_exchange_token, grant: earlier, plaintext:)

      refresh = create(:token_exchange_refresh_token, token_exchange_token: issued)

      replacement = approve

      expect(earlier.reload.revocation_reason).to eq('superseded_by_new_consent')
      expect(DelegatedTokenStore.read(plaintext)[:grant_id]).to eq(replacement.id)
      expect(issued.reload.grant_id).to eq(replacement.id)
      expect(issued.revoked_at).to be_nil
      expect(refresh.reload.grant_id).to eq(replacement.id)
      expect(refresh.revoked_at).to be_nil

      replacement.revoke!(reason: 'user_revoked')
      expect(DelegatedTokenStore.read(plaintext)).to be_nil
      expect(issued.reload.revocation_reason).to eq('user_revoked')
    end
  end

  describe '#time_remaining' do
    it 'is the time left on a remembered approval, never negative, nil otherwise' do
      grant = approve
      expect(grant.time_remaining).to be_within(1.minute).of(grant.remember_until - Time.zone.now)
      travel_to(described_class::MAX_REMEMBER.from_now + 1.day) do
        expect(grant.time_remaining).to eq(0)
      end
      expect(approve(remember: false, rails_session_id: 's').time_remaining).to be_nil
    end
  end
end
