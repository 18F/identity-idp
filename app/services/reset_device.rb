class ResetDevice
  KBA_ANSWER_OTHER = 0
  KBA_ANSWER_ERROR = -1
  VALID_KBA_AGENCY_IDS = [1, 2, 4, 5].freeze

  def initialize(user)
    @user_id = user.id
  end

  def create_request
    token = SecureRandom.uuid
    log_event(ChangePhoneEvent::EVENT_REQUEST, token)
    update do |cpr|
      {
        request_token: token, requested_at: Time.zone.now,
        request_count: cpr.request_count + 1,
        cancelled_at: nil, granted_at: nil, granted_token: nil,
        security_answer_correct: nil, answered_at: nil
      }
    end
  end

  def self.cancel_request(token)
    cpr = token.blank? ? nil : ChangePhoneRequest.find_by(request_token: token)
    return false unless cpr
    log_event(cpr.user.id, ChangePhoneEvent::EVENT_CANCEL, token)
    cpr.update(cancelled_at: Time.zone.now,
               cancel_count: cpr.cancel_count + 1,
               request_token: nil, granted_token: nil, security_answer_correct: nil)
  end

  def self.report_fraud(token)
    cpr = token.blank? ? nil : ChangePhoneRequest.find_by(request_token: token)
    return false unless cpr
    log_event(cpr.user.id, ChangePhoneEvent::EVENT_REPORT_FRAUD, token)
    now = Time.zone.now
    cpr.update(cancelled_at: now,
               cancel_count: cpr.cancel_count + 1,
               reported_fraud_at: now,
               reported_fraud_count: cpr.reported_fraud_count + 1,
               request_token: nil, granted_token: nil, security_answer_correct: nil)
  end

  def grant_request
    token = SecureRandom.uuid
    log_event(ChangePhoneEvent::EVENT_GRANT, token)
    change_phone_request.update(
      granted_at: Time.zone.now,
      granted_token: token
    )
  end

  def submit_wrong_answer(answer)
    log_event(ChangePhoneEvent::EVENT_ANSWER_WRONG, answer)
    update do |cpr|
      {
        request_token: nil, granted_token: nil,
        security_answer_correct: false,
        wrong_answer_count: cpr.wrong_answer_count + 1,
        answered_at: Time.zone.now
      }
    end
  end

  def submit_correct_answer(answer)
    log_event(ChangePhoneEvent::EVENT_ANSWER_CORRECT, answer)
    change_phone_request.update(
      request_token: nil, granted_token: nil,
      security_answer_correct: true,
      answered_at: Time.zone.now
    )
  end

  def correct_security_answer
    last_identity = User.find_by(id: @user_id)&.last_identity
    return KBA_ANSWER_OTHER unless last_identity
    agency_id = ServiceProvider.find_by(issuer: last_identity.service_provider)&.agency_id
    return agency_id if VALID_KBA_AGENCY_IDS.index(agency_id)
    KBA_ANSWER_OTHER
  end

  def process_complete
    log_event(ChangePhoneEvent::EVENT_COMPLETE, nil)
    update do |cpr|
      {
        request_token: nil, granted_token: nil, security_answer_correct: nil,
        phone_changed_count: cpr.phone_changed_count + 1
      }
    end
  end

  def self.log_event(user_id, type, data)
    ChangePhoneEvent.create(
      user_id: user_id,
      created_at: Time.zone.now,
      event_type: type,
      data: data
    )
  end

  private

  def log_event(type, data)
    ResetDevice.log_event(@user_id, type, data)
  end

  def update
    cpr = change_phone_request
    hash = yield(cpr)
    cpr.update(hash)
  end

  def change_phone_request
    ChangePhoneRequest.find_or_create_by(user_id: @user_id)
  end
end
