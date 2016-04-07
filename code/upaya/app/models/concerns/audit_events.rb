module AuditEvents
  extend ActiveSupport::Concern

  included do
    after_update :audit_update
  end

  def log(msg)
    logger.info "[#{uuid}] [#{msg}]"
  end

  private

  def audit_update
    log 'Password Created' if password_created?
    log 'Password Changed' if password_changed?
    log 'Account Locked' if locked_at_changed? && !locked_at.nil?
    log 'Authentication Successful' if current_sign_in_at_changed?
    log 'Authentication Failed' if failed_attempts_changed?
    log 'Account Created' if id_changed?
  end

  def password_created?
    confirmed_at_changed? && encrypted_password_changed?
  end

  def password_changed?
    encrypted_password_changed? && !confirmed_at_changed?
  end
end
