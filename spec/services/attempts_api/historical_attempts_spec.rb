require 'rails_helper'

RSpec.describe AttemptsApi::HistoricalAttempts do
  let(:user) do
    create(
      :user,
      :fully_registered,
      password: ControllerHelper::VALID_PASSWORD,
      email: 'email@example.com',
    )
  end
  let(:issuer) { 'this:is:a:test' }
  let(:sp) { create(:service_provider, ial: 2, issuer: issuer) }
  let(:applicant) { Idp::Constants::MOCK_IDV_APPLICANT_WITH_PHONE }
  let(:profile) do
    create(:profile, :active, user: user, initiating_service_provider_issuer: sp.issuer)
  end
  let(:mock) { double }

  subject do
    user_session = {
      "idv/attempts" => {
        "test_attempt" => "some_data",
      }
    }
    idv_session = Idv::Session.new(
      user_session: user_session,
      current_user: user,
      service_provider: sp,
    )
    idv_session.applicant = applicant.merge({ :uuid => user.uuid })
    idv_session.create_profile_from_applicant_with_password(
      user.password,
      is_enhanced_ipp: false,
      proofing_components: Idp::Constants::MOCK_IDV_APPLICANT_WITH_PHONE,
    )

    described_class.new(
      password: user.password,
      user_session: user_session,
      idv_session: idv_session,
    )
  end

  before do
    allow(IdentityConfig.store).to receive_messages(
      allowed_attempts_providers: [{issuer: sp.issuer}],
      attempts_api_enabled: true,
      historical_attempts_api_enabled: true,
    )
    allow(UserProofingEvent).to receive(:new).and_return(mock)
    allow(mock).to receive(:save).and_return(true)
    allow(UserProofingEvent).to receive(:save).and_return(true)
  end

  describe '#record_events' do
    context 'historical_attempts_api_enabled is false at the secrets level' do
      before do
        allow(IdentityConfig.store).to receive(
          :historical_attempts_api_enabled).and_return(false)
      end

      it 'does not modify or create a UserProofingEvent' do
        expect(UserProofingEvent).to_not have_received(:new)
        expect(UserProofingEvent).to_not have_received(:save)

        subject.record_events
      end
    end

    context 'service_provider is not an allowed_attempts_providers' do
      before do
        allow(IdentityConfig.store).to receive(
          :allowed_attempts_providers).and_return([])
      end

      it 'does not modify or create a UserProofingEvent' do
        expect(UserProofingEvent).to_not have_received(:new)
        expect(UserProofingEvent).to_not have_received(:save)

        subject.record_events
      end
    end
  end
end
