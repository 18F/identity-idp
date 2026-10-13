require 'rails_helper'

RSpec.describe BillableEventTrackable do
  let(:fake_controller_class) do
    Data.define(
      :ial_context,
      :current_sp,
      :current_user,
      :request_id,
      :user_session,
      :sp_session,
      :resolved_authn_context_result,
      :session,
    ) do
      include BillableEventTrackable
    end
  end

  let(:current_user) { create(:user, profiles: [active_profile]) }
  let(:current_sp) { create(:service_provider) }
  let(:ial_context) { IalContext.new(ial: 1, service_provider: current_sp) }
  let(:request_id) { SecureRandom.hex }
  let(:session_started_at) { 5.minutes.ago }
  let(:profile_sp) { create(:service_provider) }
  let(:active_profile) do
    create(
      :profile,
      :active,
      :verified,
      initiating_service_provider: profile_sp,
    )
  end

  around do |ex|
    freeze_time { ex.run }
  end

  subject(:instance) do
    fake_controller_class.new(
      ial_context:,
      current_sp:,
      current_user:,
      request_id:,
      user_session: {},
      resolved_authn_context_result: double(identity_proofing?: false),
      sp_session: {
        issuer: current_sp.issuer,
      },
      session: {
        session_started_at:,
      },
    )
  end

  describe '#track_billing_events' do
    it 'does not fail if SpReturnLog row already exists' do
      SpReturnLog.create(
        request_id: request_id,
        user_id: current_user.id,
        billable: true,
        ial: ial_context.ial,
        issuer: current_sp.issuer,
        returned_at: Time.zone.now,
      )

      expect do
        instance.track_billing_events
      end.to_not(change { SpReturnLog.count }.from(1))
    end

    it 'writes the same row as before through the shared writer, billable once per session' do
      expect(Billing::SpReturnLogWriter).to receive(:write).twice.and_call_original

      instance.track_billing_events
      first = SpReturnLog.last
      expect(first).to have_attributes(
        request_id:, user_id: current_user.id, billable: true, ial: 1,
        issuer: current_sp.issuer, profile_id: nil, profile_verified_at: nil,
        profile_requested_issuer: nil, returned_at: Time.zone.now, access_type: 'direct'
      )
      expect(instance.user_session["auth_counted_#{current_sp.issuer}ial1"]).to eq(true)

      # A later handoff in the same session writes nothing: the row for this request id exists.
      expect { instance.track_billing_events }.not_to(change { SpReturnLog.count })
    end

    it 'writes a non-billable row for a later handoff with a new request id' do
      instance.track_billing_events
      later = fake_controller_class.new(**instance.to_h, request_id: SecureRandom.hex)

      expect { later.track_billing_events }.to change { SpReturnLog.count }.by(1)
      expect(SpReturnLog.last).to have_attributes(billable: false, access_type: 'direct')
    end

    context 'for a service provider approved for delegated access' do
      let(:current_sp) { create(:service_provider, :delegation_service_provider) }
      let(:ial_context) { IalContext.new(ial: 2, service_provider: current_sp) }
      let!(:identity) do
        IdentityLinker.new(current_user, current_sp).link_identity(ial: 2)
      end

      before do
        allow(IdentityConfig.store).to receive(:token_exchange_enabled).and_return(true)
      end

      it 'links the access token the service provider will receive to the billable row' do
        instance.track_billing_events

        expect(Billing::SignInWaiverLink.read(access_token: identity.access_token))
          .to eq(SpReturnLog.last.id)
      end

      it 'points a later handoff in the same session at the session’s billable row' do
        instance.track_billing_events
        billable_row = SpReturnLog.last
        IdentityLinker.new(current_user, current_sp).link_identity(ial: 2)
        later = fake_controller_class.new(**instance.to_h, request_id: SecureRandom.hex)

        later.track_billing_events

        expect(SpReturnLog.last.billable).to eq(false)
        expect(Billing::SignInWaiverLink.read(access_token: identity.reload.access_token))
          .to eq(billable_row.id)
      end

      it 'does not fail the handoff when the link cannot be written' do
        allow(Billing::SignInWaiverLink).to receive(:write).and_raise(Redis::CannotConnectError)
        expect(NewRelic::Agent).to receive(:notice_error).with(Redis::CannotConnectError)

        expect { instance.track_billing_events }.to change { SpReturnLog.count }.by(1)
      end
    end

    it 'writes no link for an ordinary service provider' do
      IdentityLinker.new(current_user, current_sp).link_identity(ial: 1)
      expect(Billing::SignInWaiverLink).not_to receive(:write)

      instance.track_billing_events
    end

    context 'with an IAL 1 event' do
      let(:ial_context) { IalContext.new(ial: 1, service_provider: current_sp) }

      it 'does not log profile attributes on the sp_return_log' do
        expect { instance.track_billing_events }.to(change { SpReturnLog.count }.by(1))

        sp_return_log = SpReturnLog.last
        aggregate_failures do
          expect(sp_return_log.profile_id).to eq(nil)
          expect(sp_return_log.profile_verified_at).to eq(nil)
          expect(sp_return_log.profile_requested_issuer).to eq(nil)
        end
      end
    end

    context 'with an IAL 2 event' do
      let(:ial_context) { IalContext.new(ial: 2, service_provider: current_sp) }

      it 'logs profile attributes on the sp_return_log' do
        expect { instance.track_billing_events }.to(change { SpReturnLog.count }.by(1))

        sp_return_log = SpReturnLog.last
        aggregate_failures do
          expect(sp_return_log.profile_id).to eq(active_profile.id)
          expect(sp_return_log.profile_verified_at).to eq(active_profile.verified_at)
          expect(sp_return_log.profile_requested_issuer)
            .to eq(active_profile.initiating_service_provider_issuer)
          expect(sp_return_log.profile_requested_service_provider)
            .to eq(active_profile.initiating_service_provider)
        end
      end
    end
  end
end
