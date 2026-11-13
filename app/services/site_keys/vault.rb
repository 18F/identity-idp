# frozen_string_literal: true

module SiteKeys
  # Opens a person's site key with a secret they hold (their password, or a recovery code after a
  # reset) and keeps the private scalar KMS-encrypted in the session, beside a fingerprint of the
  # stored wraps so this session treats the key as locked again when another session changes them.
  class Vault
    SESSION_KEY = :encrypted_site_key
    FINGERPRINT_SESSION_KEY = :site_key_fingerprint
    UNAVAILABLE_SESSION_KEY = :site_key_unavailable
    RECOVERY_CODE_SESSION_KEY = :site_key_recovery_code

    attr_reader :user, :user_session

    # Reads the private scalar out of a session hash, for the user-information endpoint, which has
    # the session but not a live `Vault`. The value is the one this session cached at sign-in.
    def self.cached_private_key(session)
      encrypted = session[SESSION_KEY]
      return if encrypted.blank?

      Base64.strict_decode64(SessionEncryptor.new.kms_decrypt(encrypted))
    end

    def initialize(user:, user_session:, analytics: nil)
      @user = user
      @user_session = user_session
      @analytics = analytics
    end

    # Opens the key with the password just entered. A key is created only when `create` is set, so
    # a person who never signs in to a listed client never gets one. When a key has just been
    # created, or its stored recovery code was never acknowledged, a code is minted to show once.
    # @return [String, nil] the private scalar
    # @raise [MismatchError, Encryption::EncryptionError]
    def unlock(password, create: false, show_recovery_code: true)
      private_key = if record&.encrypted_private_key
                      cipher.unwrap(record.encrypted_private_key, password)
                    elsif record.nil? && create
                      create!(password)
                    end
      return unless private_key

      cache(private_key)
      ensure_recovery_code_shown(private_key) if show_recovery_code
      private_key
    end

    # Drops a wrap that failed under a password the person has just proven (the password changed
    # while the key was locked in every session), unless another session changed the row since,
    # then opens or creates as `unlock` does.
    def replace!(password, create:)
      SiteKey.transaction do
        current = SiteKey.lock.find_by(user_id: user.id)
        current.forget_password! if current && fingerprint_of(current) == fingerprint
      end
      user.reload_site_key
      unlock(password, create:)
    end

    # Opens the key with a recovery code after a reset and caches it until the next password entry
    # rewraps it.
    # @return [String, nil] the private scalar
    def recover(code)
      return unless record

      private_key = cipher.recover(record, code)
      cache(private_key) if private_key
      private_key
    end

    # @return [String, nil] the key wrapped under the new password; nil while it is locked here
    def wrap_cached_key(new_password)
      private_key = cached_private_key
      cipher.wrap(private_key, new_password) if private_key
    end

    # Stores the wrap `wrap_cached_key` made, inside the transaction that changes the password,
    # unless another session changed the row since. A key locked in this session keeps its old
    # wrap; the next sign-in finds it stale and starts over.
    def store_rewrapped!(encrypted_private_key, expected_fingerprint:)
      return if encrypted_private_key.nil?

      current = SiteKey.lock.find_by(user_id: user.id)
      return if current.nil? || fingerprint_of(current) != expected_fingerprint

      current.update!(encrypted_private_key:)
      user.association(:site_key).target = current
      remember_fingerprint
    end

    # Drops a password wrap that failed to authenticate, unless another session changed the key
    # since. The recovery-code wrap stays, so the person recovers.
    def forget_dead_password_wrap!(expected_fingerprint:)
      SiteKey.transaction do
        current = SiteKey.lock.find_by(user_id: user.id)
        current.forget_password! if current && fingerprint_of(current) == expected_fingerprint
      end
      user.reload_site_key
    end

    # Mints a fresh recovery code for the unlocked key, from the account page.
    def regenerate_recovery_code
      private_key = cached_private_key
      issue_recovery_code(private_key) if private_key
    end

    # Mints a code to show when the stored one was never acknowledged and none is pending.
    def show_unacknowledged_recovery_code
      private_key = cached_private_key
      ensure_recovery_code_shown(private_key) if private_key
    end

    # The code minted in this session, as long as it still opens the stored recovery wrap. A code
    # another session has since replaced is discarded rather than shown (fix for a race where a
    # person could acknowledge a code that no longer opens the key).
    def pending_recovery_code
      code, wrap_digest = user_session[RECOVERY_CODE_SESSION_KEY]
      return code if code && wrap_digest == recovery_wrap_digest

      user_session.delete(RECOVERY_CODE_SESSION_KEY)
      nil
    end

    # Records that the person saved the code currently stored. A code another session replaced is
    # not counted.
    # @return [Boolean]
    def acknowledge_recovery_code
      current = unlocked? && pending_recovery_code.present?
      user_session.delete(RECOVERY_CODE_SESSION_KEY)
      return false unless current && record
      return true if record.recovery_code_acknowledged_at.present?

      record.update!(recovery_code_acknowledged_at: Time.zone.now)
      remember_fingerprint
      true
    end

    def stored_fingerprint
      fingerprint
    end

    def unlocked?
      user_session[SESSION_KEY].present? &&
        user_session[FINGERPRINT_SESSION_KEY].present? &&
        user_session[FINGERPRINT_SESSION_KEY] == fingerprint
    end

    # The password would open the key but has not been entered in this session.
    def locked?
      record&.encrypted_private_key.present? && !unlocked?
    end

    def needs_password?
      locked? && !unavailable?
    end

    # The password wrap was dropped by a reset; the recovery code is needed.
    def recoverable?
      !unlocked? && record.present? && record.encrypted_private_key.nil? && record.recoverable?
    end

    def unavailable?
      user_session[UNAVAILABLE_SESSION_KEY].present?
    end

    def mark_unavailable
      user_session[UNAVAILABLE_SESSION_KEY] = true
    end

    def clear_unavailable
      user_session.delete(UNAVAILABLE_SESSION_KEY)
    end

    # What the person must do before the site key can be released in this session.
    # @return [Symbol] :ready, :needs_acknowledgement, :needs_recovery, :needs_password or
    #   :unavailable
    def status
      if unlocked?
        return :needs_acknowledgement if needs_acknowledgement?

        return :ready
      end
      return :needs_recovery if recoverable?
      return :unavailable if unavailable?

      :needs_password
    end

    # @return [String, nil] the private scalar, while it is unlocked in this session
    def private_key
      cached_private_key
    end

    private

    attr_reader :analytics

    def record
      user.site_key
    end

    def cipher
      @cipher ||= Cipher.new(user)
    end

    def needs_acknowledgement?
      pending_recovery_code.present? || record&.recovery_code_acknowledged_at.nil?
    end

    # The savepoint keeps a lost race with another session from poisoning an enclosing
    # transaction; the winner's key is opened instead.
    def create!(password)
      key_pair = KeyPair.generate
      private_key = key_pair.private_bytes
      SiteKey.transaction(requires_new: true) do
        SiteKey.create!(
          user:,
          public_key: key_pair.public_jwk.to_json,
          encrypted_private_key: cipher.wrap(private_key, password),
        )
      end
      user.reload_site_key
      analytics&.site_key_created
      private_key
    rescue ActiveRecord::RecordNotUnique
      cipher.unwrap(user.reload_site_key.encrypted_private_key, password)
    end

    # Mints a code, wraps the key under it and holds the plaintext to show once, when the stored
    # code was never acknowledged and none is pending.
    def ensure_recovery_code_shown(private_key)
      return if record.recovery_code_acknowledged_at.present? || pending_recovery_code.present?

      issue_recovery_code(private_key)
    end

    def issue_recovery_code(private_key)
      code = RecoveryCode.generate
      record.update!(recovery_code_attributes(private_key, code))
      remember_fingerprint
      remember_pending_recovery_code(code)
    end

    def recovery_code_attributes(private_key, code)
      {
        encrypted_private_key_recovery_code: cipher.wrap(private_key, RecoveryCode.normalize(code)),
        recovery_code_generated_at: Time.zone.now,
        recovery_code_acknowledged_at: nil,
      }
    end

    # Ties the pending code to the wrap it opens, so it is dropped once another session replaces it.
    def remember_pending_recovery_code(code)
      user_session[RECOVERY_CODE_SESSION_KEY] = [code, recovery_wrap_digest]
    end

    def recovery_wrap_digest
      wrap = record&.encrypted_private_key_recovery_code
      Digest::SHA256.hexdigest(wrap) if wrap
    end

    def cache(private_key)
      user_session[SESSION_KEY] =
        SessionEncryptor.new.kms_encrypt(Base64.strict_encode64(private_key))
      remember_fingerprint
      private_key
    end

    def remember_fingerprint
      user_session[FINGERPRINT_SESSION_KEY] = fingerprint
    end

    def fingerprint
      fingerprint_of(record)
    end

    # The fingerprint covers every stored wrap, so acknowledging a code or dropping a wrap in
    # another session re-locks this one.
    def fingerprint_of(site_key)
      return if site_key.nil?

      Digest::SHA256.hexdigest(site_key.wraps.sort.flatten.join("\n"))
    end

    def cached_private_key
      return unless unlocked?

      Base64.strict_decode64(SessionEncryptor.new.kms_decrypt(user_session[SESSION_KEY]))
    end
  end
end
