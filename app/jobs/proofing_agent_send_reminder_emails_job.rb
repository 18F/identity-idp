# frozen_string_literal: true

class ProofingAgentSendReminderEmailsJob < ApplicationJob
  queue_as :long_running

  def perform(_now)
    start_time = Time.zone.now
    processed_uuids = []

    reminder_email_users.each do |user|
      send_reminder_email(user)
      processed_uuids << user.uuid
    rescue StandardError => e
      user_analytics(user).proofing_agent_reminder_email_job_error(exception: e.message)
    end

    remove_reminder_email_users(processed_uuids)

    job_analytics.proofing_agent_reminder_email_job_completed(
      processed_count: processed_uuids.count,
      duration_sec: cal_duration_in_seconds(start_time),
    )
  end

  private

  def reminder_email_users
    User.where(uuid: reminder_email_user_uuids)
  end

  def reminder_email_user_uuids
    reminder_email_user_set.find_by_time_range(
      0,
      (Time.zone.now - send_reminder_email_after_hours).to_i,
    )
  end

  def reminder_email_user_set
    Idv::ProofingAgent::ReminderEmailUserSet.new
  end

  def send_reminder_email_after_hours
    IdentityConfig.store.idv_proofing_agent_send_reminder_email_after_hours.hours
  end

  def send_reminder_email(user)
    # Skip (but still remove from the set) users who have already confirmed their account or
    # whose proofing window has expired.
    return unless user.proofing_agent_user_awaiting_binding?

    results = user.pending_agent_proofed_user
    return if results.blank? || results.verified_at.blank?

    ProofingAgent::ReminderEmailSender.new(
      user: user,
      analytics: user_analytics(user),
      service_provider: service_provider_for(user),
    ).call(
      verified_at: results.verified_at,
      proofing_agent_id: results.proofing_agent_id,
      proofing_location_id: results.proofing_location_id,
      correlation_id: results.correlation_id,
      transaction_id: results.transaction_id,
    )
  end

  def service_provider_for(user)
    issuer = user.pending_agent_proofed_document_capture_session&.issuer
    ServiceProvider.find_by(issuer: issuer) if issuer.present?
  end

  def user_analytics(user)
    Analytics.new(
      user:,
      request: nil,
      session: {},
      sp: user.pending_agent_proofed_document_capture_session&.issuer,
    )
  end

  def remove_reminder_email_users(uuids)
    reminder_email_user_set.remove_uuids(uuids)
  end

  def job_analytics
    Analytics.new(user: AnonymousUser.new, request: nil, session: {}, sp: nil)
  end

  def cal_duration_in_seconds(start_time)
    (Time.zone.now - start_time).seconds.round(2)
  end
end
