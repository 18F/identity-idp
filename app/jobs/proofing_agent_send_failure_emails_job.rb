# frozen_string_literal: true

class ProofingAgentSendFailureEmailsJob < ApplicationJob
  queue_as :long_running

  def perform(_now)
    start_time = Time.zone.now
    processed_uuids = []

    failure_email_users.each do |user|
      send_failure_email(user)
      processed_uuids << user.uuid
    rescue StandardError => e
      user_analytics(user).proofing_agent_failure_email_job_error(exception: e.message)
    end

    remove_failure_email_users(processed_uuids)

    job_analytics.proofing_agent_failure_email_job_completed(
      processed_count: processed_uuids.count,
      duration_sec: cal_duration_in_seconds(start_time),
    )
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

    ProofingAgent::FailureEmailSender.new(user: user, analytics: user_analytics(user)).call(
      visited_at: (doc_session.requested_at || Time.zone.now).iso8601,
      reason: results.reason,
      proofing_agent_id: results.proofing_agent_id,
      proofing_location_id: results.proofing_location_id,
      correlation_id: results.correlation_id,
      transaction_id: results.transaction_id,
    )
  end

  def user_analytics(user)
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

  def job_analytics
    Analytics.new(user: AnonymousUser.new, request: nil, session: {}, sp: nil)
  end

  def cal_duration_in_seconds(start_time)
    (Time.zone.now - start_time).seconds.round(2)
  end
end
