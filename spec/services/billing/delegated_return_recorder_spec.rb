require 'rails_helper'

# MyBenefits Assistant (the service provider) exchanges the access token of a signed-in,
# identity-verified person for a delegated token at Housing Assistance Records.
RSpec.describe Billing::DelegatedReturnRecorder do
  let(:profile_sp) { create(:service_provider, issuer: 'urn:gov:gsa:openidconnect:sp:proofer') }
  let(:profile) { create(:profile, :active, :verified, initiating_service_provider: profile_sp) }
  let(:user) { create(:user, :fully_registered, profiles: [profile]) }
  let(:service_provider) do
    create(
      :service_provider, :delegation_service_provider,
      issuer: 'urn:gov:gsa:openidconnect:sp:mybenefits', friendly_name: 'MyBenefits Assistant'
    )
  end
  let(:application) do
    create(
      :service_provider, :delegation_application,
      issuer: 'urn:gov:gsa:openidconnect:sp:housing_records',
      friendly_name: 'Housing Assistance Records'
    )
  end
  let(:billing_issuer) { nil }
  let(:resource_server) do
    create(:token_exchange_resource_server, service_provider: application, billing_issuer:)
  end
  let(:identity_ial) { 2 }
  let(:identity) do
    IdentityLinker.new(user, service_provider).link_identity(
      ial: identity_ial, rails_session_id: SecureRandom.hex,
      acr_values: Saml::Idp::Constants::IAL_VERIFIED_ACR
    )
  end
  let(:subject_token) { identity.access_token }
  let(:grant) do
    TokenExchangeGrant.approve!(
      user:, service_provider:, application:, source: 'consent_screen', remember: true,
    )
  end
  let(:issued) do
    create(:token_exchange_token, grant:, resource_server:, service_provider:, user:)
  end
  let(:analytics) { FakeAnalytics.new }

  subject(:recorder) do
    described_class.new(
      issued:, grant:, resource_server:, service_provider:, identity:, subject_token:,
    )
  end

  before do
    allow(Analytics).to receive(:new).and_return(analytics)
    allow(IdentityConfig.store).to receive(:token_exchange_billing_waiver_cache_seconds)
      .and_return(3600)
  end

  around { |ex| freeze_time { ex.run } }

  def delegated_rows
    SpReturnLog.where(access_type: 'delegated')
  end

  describe '#call' do
    it 'writes the agency row under the application issuer, billable, at the sign-in IAL' do
      row = recorder.call

      expect(row).to be_persisted
      expect(row).to have_attributes(
        issuer: application.issuer,
        user_id: user.id,
        ial: 2,
        billable: true,
        access_type: 'delegated',
        request_id: "tx:#{grant.delegation_id}:#{application.issuer}:2",
        returned_at: Time.zone.now,
        profile_id: profile.id,
        profile_verified_at: profile.verified_at,
        profile_requested_issuer: profile_sp.issuer,
      )
    end

    it 'links the row to the token issuance record' do
      row = recorder.call

      link = row.billing_adjustments.delegated_token_issued.sole
      expect(link.token_exchange_token).to eq(issued)
      expect(link.delegated_return_log).to be_nil
    end

    it 'stores no token value anywhere' do
      recorder.call

      expect(SpReturnLog.pluck(:request_id).join).not_to include(subject_token)
      REDIS_POOL.with do |client|
        expect(client.keys('*')).not_to include(a_string_including(subject_token))
      end
    end

    context 'when the API bills to another issuer' do
      let(:billing_issuer) { 'urn:gov:gsa:openidconnect:sp:housing_billing' }

      it 'writes the row under that issuer' do
        row = recorder.call
        expect(row.issuer).to eq(billing_issuer)
        expect(row.request_id).to eq("tx:#{grant.delegation_id}:#{billing_issuer}:2")
      end
    end

    context 'when the service provider signed the person in at IALmax' do
      let(:identity_ial) { 0 }

      it 'bills IAL2 for a verified person, never the stored 0' do
        expect(recorder.call.ial).to eq(2)
      end
    end

    context 'for a second exchange under the same approval' do
      let(:later_token) do
        create(:token_exchange_token, grant:, resource_server:, service_provider:, user:)
      end

      before { recorder.call }

      it 'keeps a non-billable trail row with a random id and links it to its token' do
        trail = nil
        expect do
          trail = described_class.new(
            issued: later_token, grant:, resource_server:, service_provider:, identity:,
            subject_token:
          ).call
        end.to change { delegated_rows.count }.by(1)

        expect(trail.billable).to eq(false)
        expect(trail.request_id).not_to start_with('tx:')
        expect(trail.billing_adjustments.delegated_token_issued.sole.token_exchange_token)
          .to eq(later_token)
        expect(delegated_rows.where(billable: true).count).to eq(1)
      end

      it 'leaves the enclosing transaction usable after the collision' do
        TokenExchangeToken.transaction do
          described_class.new(
            issued: later_token, grant:, resource_server:, service_provider:, identity:,
            subject_token:
          ).call
          later_token.update!(aal: 3)
        end
        expect(later_token.reload.aal).to eq(3)
        expect(delegated_rows.count).to eq(2)
      end
    end

    describe 'waiving the service provider sign-in' do
      let!(:sign_in_row) do
        create(
          :sp_return_log, user_id: user.id, issuer: service_provider.issuer, ial: 2,
                          billable: true, access_type: 'direct', returned_at: Time.zone.now
        )
      end

      def exclusion
        sign_in_row.billing_adjustments.exclude_from_billing.sole
      end

      context 'with the link written at the handoff' do
        before do
          Billing::SignInWaiverLink.write(
            access_token: subject_token,
            sp_return_log_id: sign_in_row.id,
          )
        end

        it 'excludes the sign-in row, pointing at the agency row and the token' do
          row = recorder.call

          expect(exclusion).to have_attributes(
            delegated_return_log: row, token_exchange_token: issued,
          )
          expect(exclusion).to be_resolved_via_cache
          expect(sign_in_row.excluded_from_billing?).to eq(true)
          expect(analytics).to have_logged_event(
            :delegated_billing_waiver,
            outcome: 'cache_hit', already_waived: false,
            service_provider_issuer: service_provider.issuer, billing_issuer: application.issuer
          )
        end

        it 'never updates the sign-in row itself' do
          expect { recorder.call }.not_to(change { sign_in_row.reload.attributes })
        end

        it 'ignores a cached id that belongs to another user' do
          other = create(
            :sp_return_log, user_id: create(:user).id,
                            issuer: service_provider.issuer, ial: 2, billable: true
          )
          Billing::SignInWaiverLink.write(access_token: subject_token, sp_return_log_id: other.id)

          recorder.call

          expect(other.billing_adjustments).to be_empty
          expect(exclusion).to be_resolved_via_database_fallback
        end

        it 'records a second agency being billed for the same sign-in' do
          recorder.call
          # A second agency: its own application (so its own billing issuer), approval and API.
          other_application = create(
            :service_provider, :delegation_application,
            issuer: 'urn:gov:gsa:openidconnect:sp:retirement_benefits',
            agency: create(:agency, name: 'National Retirement Administration')
          )
          other_grant = TokenExchangeGrant.approve!(
            user:, service_provider:, application: other_application,
            source: 'account_page', remember: true
          )
          other_api = create(:token_exchange_resource_server, service_provider: other_application)
          other_token = create(
            :token_exchange_token, grant: other_grant, resource_server: other_api,
                                   service_provider:, user:
          )

          described_class.new(
            issued: other_token, grant: other_grant, resource_server: other_api,
            service_provider:, identity:, subject_token:
          ).call

          expect(sign_in_row.billing_adjustments.exclude_from_billing.count).to eq(2)
          expect(analytics).to have_logged_event(
            :delegated_billing_waiver, hash_including(outcome: 'cache_hit', already_waived: true)
          )
        end

        it 'writes no waiver for a trail row' do
          recorder.call
          later_token = create(
            :token_exchange_token, grant:, resource_server:, service_provider:, user:
          )

          expect do
            described_class.new(
              issued: later_token, grant:, resource_server:, service_provider:, identity:,
              subject_token:
            ).call
          end.not_to(change { SpReturnLogBillingAdjustment.exclude_from_billing.count })
        end
      end

      context 'once the link has lapsed' do
        it 'finds the sign-in row from the database, scoped to this sign-in' do
          # Earlier sign-ins to the service provider, and this sign-in at another issuer, are
          # not this sign-in's row.
          create(
            :sp_return_log, user_id: user.id, issuer: service_provider.issuer, ial: 2,
                            billable: true, returned_at: 2.days.ago
          )
          create(
            :sp_return_log, user_id: user.id, issuer: application.issuer, ial: 2,
                            billable: true, returned_at: Time.zone.now
          )

          row = recorder.call

          expect(exclusion).to have_attributes(
            delegated_return_log: row, token_exchange_token: issued,
          )
          expect(exclusion).to be_resolved_via_database_fallback
          expect(SpReturnLogBillingAdjustment.exclude_from_billing.count).to eq(1)
          expect(analytics).to have_logged_event(
            :delegated_billing_waiver, hash_including(outcome: 'db_fallback')
          )
        end

        it 'does not pick a non-billable row or a delegated row' do
          sign_in_row.destroy!
          create(
            :sp_return_log, user_id: user.id, issuer: service_provider.issuer, ial: 2,
                            billable: false, returned_at: Time.zone.now
          )
          create(
            :sp_return_log, user_id: user.id, issuer: service_provider.issuer, ial: 2,
                            billable: true, access_type: 'delegated', returned_at: Time.zone.now
          )

          recorder.call

          expect(SpReturnLogBillingAdjustment.exclude_from_billing).to be_empty
          expect(analytics).to have_logged_event(
            :delegated_billing_waiver, hash_including(outcome: 'not_found')
          )
        end

        it 'leaves the service provider billed when no row is found' do
          sign_in_row.destroy!

          row = recorder.call

          expect(row).to be_persisted
          expect(SpReturnLogBillingAdjustment.exclude_from_billing).to be_empty
          expect(analytics).to have_logged_event(
            :delegated_billing_waiver,
            outcome: 'not_found', already_waived: false,
            service_provider_issuer: service_provider.issuer, billing_issuer: application.issuer
          )
        end
      end
    end

    context 'when billing fails' do
      it 'reports the error and never raises' do
        allow(Billing::SignInWaiverLink).to receive(:read).and_raise(Redis::CannotConnectError)
        expect(NewRelic::Agent).to receive(:notice_error).with(Redis::CannotConnectError)

        expect(recorder.call).to be_nil
        expect(delegated_rows).to be_empty
      end

      it 'leaves the enclosing transaction usable' do
        allow(SpReturnLogBillingAdjustment).to receive(:create!).and_raise(ActiveRecord::StatementInvalid)
        allow(NewRelic::Agent).to receive(:notice_error)

        TokenExchangeToken.transaction do
          recorder.call
          issued.update!(aal: 3)
        end
        expect(issued.reload.aal).to eq(3)
      end
    end
  end
end
