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
      :sp_session_ial,
      :session,
    ) do
      include BillableEventTrackable
    end
  end

  let(:current_user) { create(:user) }
  let(:current_sp) { create(:service_provider) }
  let(:ial_context) { IalContext.new(ial: 1, service_provider: current_sp) }
  let(:request_id) { SecureRandom.hex }
  let(:session_started_at) { 5.minutes.ago }

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
      sp_session_ial: 1,
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
        requested_at: session_started_at,
        returned_at: Time.zone.now,
      )

      expect do
        instance.track_billing_events
      end.to_not(change { SpReturnLog.count }.from(1))
    end
  end
end
