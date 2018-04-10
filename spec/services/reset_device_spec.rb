require 'rails_helper'

describe ResetDevice do
  include Rails.application.routes.url_helpers

  let(:user) { create(:user) }

  describe '#create_request' do
    it 'creates a new reset device request on the user' do
      ResetDevice.new(user).create_request
      cpr = user.change_phone_request
      expect(cpr.request_token).to be_present
      expect(cpr.requested_at).to be_present
      expect(cpr.cancelled_at).to be_nil
      expect(cpr.granted_at).to be_nil
      expect(cpr.granted_token).to be_nil
      expect(cpr.security_answer_correct).to be_nil
      expect(cpr.answered_at).to be_nil
      expect(cpr.request_count).to be(1)
    end

    it 'creates a new reset device request in the db' do
      ResetDevice.new(user).create_request
      cpr = ChangePhoneRequest.find_by(user_id: user.id)
      expect(cpr.request_token).to be_present
      expect(cpr.requested_at).to be_present
      expect(cpr.cancelled_at).to be_nil
      expect(cpr.granted_at).to be_nil
      expect(cpr.granted_token).to be_nil
      expect(cpr.security_answer_correct).to be_nil
      expect(cpr.answered_at).to be_nil
      expect(cpr.request_count).to be(1)
    end

    it 'creates a change phone request event' do
      ResetDevice.new(user).create_request
      event = expect_event(user, ChangePhoneEvent::EVENT_REQUEST)
      expect(event.data).to be_present
    end
  end

  describe '#cancel_request' do
    it 'removes tokens from a reset device request' do
      ResetDevice.new(user).create_request
      ResetDevice.cancel_request(user.change_phone_request.request_token)
      cpr = ChangePhoneRequest.find_by(user_id: user.id)
      expect(cpr.request_token).to_not be_present
      expect(cpr.granted_token).to_not be_present
      expect(cpr.requested_at).to be_present
      expect(cpr.cancelled_at).to be_present
      expect(cpr.cancel_count).to be(1)
      expect(cpr.security_answer_correct).to be_nil
    end

    it 'does not raise an error for a cancel request with a blank token' do
      ResetDevice.cancel_request('')
    end

    it 'does not raise an error for a cancel request with a nil token' do
      ResetDevice.cancel_request('')
    end

    it 'does not raise an error for a cancel request with a bad token' do
      ResetDevice.cancel_request('ABC')
    end

    it 'creates a change phone cancel event' do
      ResetDevice.new(user).create_request
      ResetDevice.cancel_request(user.change_phone_request.request_token)
      event = expect_event(user, ChangePhoneEvent::EVENT_CANCEL)
      expect(event.data).to be_present
    end
  end

  describe '#report_fraud' do
    it 'removes tokens from the request' do
      ResetDevice.new(user).create_request
      ResetDevice.report_fraud(user.change_phone_request.request_token)
      cpr = ChangePhoneRequest.find_by(user_id: user.id)
      expect(cpr.request_token).to_not be_present
      expect(cpr.granted_token).to_not be_present
      expect(cpr.requested_at).to be_present
      expect(cpr.cancelled_at).to be_present
      expect(cpr.cancel_count).to be(1)
      expect(cpr.security_answer_correct).to be_nil
      expect(cpr.reported_fraud_at).to be_present
      expect(cpr.reported_fraud_count).to be(1)
    end

    it 'does not raise an error for a fraud request with a blank token' do
      token_found = ResetDevice.report_fraud('')
      expect(token_found).to be(false)
    end

    it 'does not raise an error for a cancel request with a nil token' do
      token_found = ResetDevice.report_fraud('')
      expect(token_found).to be(false)
    end

    it 'does not raise an error for a cancel request with a bad token' do
      token_found = ResetDevice.report_fraud('ABC')
      expect(token_found).to be(false)
    end

    it 'creates a change phone cancel event' do
      ResetDevice.new(user).create_request
      token_found = ResetDevice.report_fraud(user.change_phone_request.request_token)
      expect(token_found).to_not be(false)
      event = expect_event(user, ChangePhoneEvent::EVENT_REPORT_FRAUD)
      expect(event.data).to be_present
    end
  end

  describe '#grant_request' do
    it 'adds a notified at timestamp and granted token to the user' do
      rd = ResetDevice.new(user)
      rd.create_request
      rd.grant_request
      cpr = ChangePhoneRequest.find_by(user_id: user.id)
      expect(cpr.granted_at).to be_present
      expect(cpr.granted_token).to be_present
    end

    it 'creates a change phone grant event' do
      rd = ResetDevice.new(user)
      rd.create_request
      rd.grant_request
      event = expect_event(user, ChangePhoneEvent::EVENT_GRANT)
      expect(event.data).to be_present
    end
  end

  describe '#process_complete' do
    it 'removes a reset device request from the user' do
      rd = ResetDevice.new(user)
      rd.create_request
      rd.grant_request
      rd.process_complete
      cpr = ChangePhoneRequest.find_by(user_id: user.id)
      expect(cpr.request_token).to_not be_present
      expect(cpr.granted_token).to_not be_present
    end

    it 'removes a reset device request from the db' do
      rd = ResetDevice.new(user)
      rd.create_request
      rd.process_complete
      cpr = ChangePhoneRequest.find_by(user_id: user.id)
      expect(cpr.request_token).to_not be_present
      expect(cpr.granted_token).to_not be_present
    end

    it 'gracefully handles a remove reset device request when there is not one' do
      rd = ResetDevice.new(user)
      rd.create_request
      rd.process_complete
      cpr = ChangePhoneRequest.find_by(user_id: user.id)
      expect(cpr.request_token).to_not be_present
    end

    it 'creates a change phone complete event' do
      rd = ResetDevice.new(user)
      rd.create_request
      rd.grant_request
      rd.process_complete
      event = expect_event(user, ChangePhoneEvent::EVENT_COMPLETE)
      expect(event.data).to be_nil
    end
  end

  describe '#submit_wrong_answer' do
    it 'marks the wrong answer in the db' do
      ResetDevice.new(user).submit_wrong_answer(1)
    end

    it 'creates a change phone wrong answer event' do
      ResetDevice.new(user).submit_wrong_answer(1)
      event = expect_event(user, ChangePhoneEvent::EVENT_ANSWER_WRONG)
      expect(event.data).to eq('1')
    end
  end

  describe '#submit_correct_answer' do
    it 'marks the correct answer in the db' do
      ResetDevice.new(user).submit_correct_answer(0)
    end

    it 'creates a change phone correct answer event' do
      ResetDevice.new(user).submit_correct_answer(0)
      event = expect_event(user, ChangePhoneEvent::EVENT_ANSWER_CORRECT)
      expect(event.data).to eq('0')
    end
  end

  describe '#correct_security_answer' do
    it 'returns 0 - other if the user has not visited an agency' do
      answer = ResetDevice.new(user).correct_security_answer
      expect(answer).to eq(0)
    end

    it 'returns the agency id of the agency visited by the user' do
      Identity.create(user_id: user.id,
                      service_provider: 'urn:gov:gsa:openidconnect:test',
                      session_uuid: SecureRandom.uuid)
      answer = ResetDevice.new(user).correct_security_answer
      expect(answer).to eq(1) # in the service_providers.yml
    end

    it 'returns other if the agency is not listed as a valid agency id' do
      Identity.create(user_id: user.id,
                      service_provider: 'bad:sp',
                      session_uuid: SecureRandom.uuid)
      answer = ResetDevice.new(user).correct_security_answer
      expect(answer).to eq(0)
    end
  end

  private

  def expect_event(user, event_type)
    event = ChangePhoneEvent.where(event_type: event_type, user_id: user.id).first
    expect(event.created_at).to be_present
    event
  end
end
