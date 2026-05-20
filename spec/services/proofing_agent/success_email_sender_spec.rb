# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ProofingAgent::SuccessEmailSender do
  let(:user) { create(:user, :fully_registered) }
  let(:analytics) { FakeAnalytics.new }
  let(:verified_at) { Time.zone.now.iso8601 }
  let(:proofing_agent_id) { SecureRandom.uuid }
  let(:proofing_location_id) { SecureRandom.uuid }
  let(:correlation_id) { SecureRandom.uuid }
  let(:transaction_id) { SecureRandom.uuid }

  subject(:sender) { described_class.new(user: user, analytics: analytics) }

  describe '#call' do
    before do
      ActionMailer::Base.deliveries.clear
    end

    it 'delivers a confirmation email to each confirmed email address' do
      expect do
        sender.call(
          verified_at: verified_at,
          proofing_agent_id: proofing_agent_id,
          proofing_location_id: proofing_location_id,
          correlation_id: correlation_id,
          transaction_id: transaction_id,
        )
      end.to change { ActionMailer::Base.deliveries.count }.by(user.confirmed_email_addresses.count)

      deliveries = ActionMailer::Base.deliveries
      user.confirmed_email_addresses.each_with_index do |email_address, idx|
        expect(deliveries[idx].to).to eq([email_address.email])
        expect(deliveries[idx].subject).to eq(
          I18n.t('user_mailer.agent_proofing_succeeded.subject'),
        )
      end
    end

    it 'logs the idv_proofing_agent_profile_confirmation_email_sent analytics event' do
      sender.call(
        verified_at: verified_at,
        proofing_agent_id: proofing_agent_id,
        proofing_location_id: proofing_location_id,
        correlation_id: correlation_id,
        transaction_id: transaction_id,
      )

      expected_expiration = Idv::ProofingAgent::AgentProofingSucceededPresenter
        .deadline_for(verified_at: verified_at)

      expect(analytics).to have_logged_event(
        :idv_proofing_agent_profile_confirmation_email_sent,
        user_id: user.uuid,
        proofing_agent: {
          correlation_id: correlation_id,
          transaction_id: transaction_id,
          agent_id: proofing_agent_id,
          location_id: proofing_location_id,
        },
        expiration_date: expected_expiration,
      )
    end
  end
end
