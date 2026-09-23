# frozen_string_literal: true

class ProofingAgentSendFailureEmailsJob < ApplicationJob
  queue_as :long_running

  def perform(_now)
    # Consider doing this with pagination
    completed_uuids = []

    failure_email_users.each do |user|
      send_failure_email(user)
      completed_uuids << user.uuid
    end

    remove_failure_email_users(completed_uuids)
  end

  private

  def failure_email_users
    User.where(uuid: failure_email_user_uuids).includes(:current_proofing_agent_session)
  end

  def failure_email_user_uuids
    failure_email_user_set.find_by_time_range(0, calc_offset_unix_timestamp)
  end

  def failure_email_user_set
    Idv::ProofingAgent::FailureEmailUserSet.new
  end

  def calc_offset_unix_timestamp
    (Time.zone.now - send_failure_email_after_minutes).to_i
  end

  def send_failure_email_after_minutes
    IdentityConfig.store.idv_proofing_agent_send_failure_email_after_min.minutes
  end

  def send_failure_email(user)
    doc_session = user.current_proofing_agent_session
    results = doc_session.load_agent_proofed_user
    ProofingAgent::FailureEmailSender.new(user: user, analytics: analytics(user)).call(
      visited_at: (doc_session.requested_at || Time.zone.now).iso8601,
      reason: results.reason,
      proofing_agent_id: results.proofing_agent_id,
      proofing_location_id: results.proofing_location_id,
      correlation_id: results.correlation_id,
      transaction_id: results.transaction_id,
    )
  end

  def analytics(user)
    Analytics.new(
      user:,
      request: nil,
      session: {},
      sp: user.current_proofing_agent_session&.issuer,
    )
  end

  def remove_failure_email_users(uuids)
    failure_email_user_set.remove_uuids(uuids)
  end
end
