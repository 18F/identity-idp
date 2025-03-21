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
