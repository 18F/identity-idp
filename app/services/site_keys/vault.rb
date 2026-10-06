# frozen_string_literal: true

module SiteKeys
  # Unlocks a user's site key root with a secret they hold and keeps it KMS-encrypted in the
  # session, alongside a fingerprint of the stored wraps so the session re-locks when another
  # session changes them.
  class Vault
    SESSION_KEY = :encrypted_site_key_root
    FINGERPRINT_SESSION_KEY = :site_key_root_fingerprint
    RECOVERY_CODE_SESSION_KEY = :site_key_recovery_code
    UNAVAILABLE_SESSION_KEY = :site_key_root_unavailable
    ROOT_BYTES = 32
    SITE_KEY_SALT = 'login.gov site key v1'

    attr_reader :user, :user_session

    def initialize(user:, user_session:, analytics: nil)
      @user = user
      @user_session = user_session
      @analytics = analytics
    end

    # Unwraps the root with the password just entered. A root is only created when `create`
    # is set, so users who never sign in to a site key SP never get one. A root recovered
    # earlier in this session is wrapped under the password here, and a root nothing can open is
    # replaced, unless `repair` is false (before the second factor).
    # @return [String, nil] the root
    # @raise [RootMismatchError, Encryption::EncryptionError]
    def unlock(password, create: false, show_recovery_code: true, repair: true)
      return unless enabled?

      root = if record&.encrypted_root
               cipher.unwrap(record.encrypted_root, password)
             elsif record && repair
               rewrap_recovered_root(password) || replace_dead_root(password, create:)
             elsif create
               create_root!(password)
             end
      return if root.nil?

      cache(root)
      ensure_recovery_code_shown(root) if show_recovery_code
      root
    end

    # Replaces the root whose stored wraps had `expected_fingerprint`; does nothing when another
    # session has changed or deleted it since.
    def replace!(password, expected_fingerprint: fingerprint)
      return unless enabled?

      root = SiteKeyRoot.transaction do
        current = SiteKeyRoot.lock.find_by(user_id: user.id)
        next if current.nil? || fingerprint_of(current) != expected_fingerprint

        create_root!(password, replace: current)
      end
      user.reload_site_key_root
      cache(root) if root
    end

    # @return [String, nil] the root, cached until the next password entry re-wraps it
    def recover(code)
      return unless enabled? && record

      root = cipher.recover(record, code)
      cache(root) if root
      root
    end

    def cache_recovered_root(root)
      cache(root)
    end

    # @return [String, nil] nil while the root is locked in this session
    def wrap_cached_root(new_password)
      root = cached_root
      cipher.wrap(root, new_password) if root
    end

    def store_root!(encrypted_root)
      store_wrap!(:encrypted_root, encrypted_root)
    end

    # Stores a root re-wrapped by `wrap_cached_root`, or drops the password wrap when it could
    # not be re-wrapped (locked in this session, or changed by another session since), so a
    # password change never leaves a root wrapped under a password the user no longer has.
    # Call inside the transaction that changes the password.
    def store_root_or_forget!(encrypted_root, expected_fingerprint:)
      current = SiteKeyRoot.lock.find_by(user_id: user.id)
      user.association(:site_key_root).target = current
      return if current.nil?

      if encrypted_root && fingerprint_of(current) == expected_fingerprint
        store_root!(encrypted_root)
      else
        current.forget_password!
        nil
      end
    end

    def stored_fingerprint
      fingerprint
    end

    # Keeps the personal key wrap in step with a newly minted personal key. While the root is
    # locked the previous key's wrap is dropped instead, unless nothing else could open the
    # root. Runs in a savepoint and never raises, so site keys cannot break identity
    # verification.
    def wrap_personal_key(personal_key, password: nil)
      return unless enabled? && record

      secret = RecoveryCode.normalize(personal_key)
      return if secret.nil?

      SiteKeyRoot.transaction(requires_new: true) do
        root = unlock(password, show_recovery_code: false) if password.present?
        root ||= cached_root
        if root
          store_wrap!(:encrypted_root_personal_key, cipher.wrap(root, secret))
        elsif record.encrypted_root.present? || record.recovery_code_usable?
          clear_personal_key_wrap
        end
      end
    rescue Encryption::EncryptionError, ActiveRecord::ActiveRecordError
      nil
    end

    # A personal key used as a second factor is retired and its replacement is never shown.
    # Opens the root with it while possible, then drops its wrap unless nothing else would be
    # left to open the root.
    def consume_personal_key(personal_key)
      return unless enabled? && record

      open_with_personal_key(personal_key) if !unlocked? && record.encrypted_root.nil?
      clear_personal_key_wrap if record.encrypted_root.present? || record.recovery_code_usable?
    rescue ActiveRecord::ActiveRecordError
      nil
    end

    # Drops a password wrap that failed to authenticate, unless another session has changed the
    # root since.
    def forget_dead_password_wrap!(expected_fingerprint:)
      SiteKeyRoot.transaction do
        current = SiteKeyRoot.lock.find_by(user_id: user.id)
        current.forget_password! if current && fingerprint_of(current) == expected_fingerprint
      end
      user.reload_site_key_root
    end

    def regenerate_recovery_code
      root = cached_root
      issue_recovery_code(root) if root
    end

    # Mints a code to show when the stored one was never acknowledged and none is pending.
    def show_unacknowledged_recovery_code
      root = cached_root
      ensure_recovery_code_shown(root) if root
    end

    def pending_recovery_code
      user_session[RECOVERY_CODE_SESSION_KEY]
    end

    # Only counts when the code shown is still the one stored; a code another session has
    # replaced is discarded.
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

    def unlocked?
      user_session[SESSION_KEY].present? &&
        user_session[FINGERPRINT_SESSION_KEY].present? &&
        user_session[FINGERPRINT_SESSION_KEY] == fingerprint
    end

    # The password would unlock the root but has not been entered in this session.
    def locked?
      enabled? && record&.encrypted_root.present? && !unlocked?
    end

    def needs_password?
      locked? && !unavailable?
    end

    # The password wrap was dropped by a reset; the recovery code or personal key is needed.
    def recoverable?
      enabled? && !unlocked? && record.present? && record.encrypted_root.nil? &&
        record.recoverable?
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

    # What the user must do before a site key can be released in this session.
    # @return [Symbol] :ready, :needs_password, :needs_recovery, :needs_acknowledgement or
    #   :unavailable
    def status
      if unlocked?
        return :needs_password if record.encrypted_root.nil?
        if pending_recovery_code.present? || record.recovery_code_acknowledged_at.nil?
          return :needs_acknowledgement
        end
        return :ready
      end
      return :unavailable if unavailable?
      return :needs_recovery if recoverable?

      :needs_password
    end

    def site_key(issuer)
      root = cached_root
      raise SealError, 'site key root is locked' if root.nil?

      OpenSSL::KDF.hkdf(root, salt: SITE_KEY_SALT, info: issuer.to_s, length: 32, hash: 'SHA256')
    end

    private

    attr_reader :analytics

    def enabled?
      IdentityConfig.store.site_key_enabled
    end

    def record
      user.site_key_root
    end

    def cipher
      @cipher ||= RootCipher.new(user)
    end

    def open_with_personal_key(personal_key)
      secret = RecoveryCode.normalize(personal_key)
      root = cipher.try_unwrap(record.encrypted_root_personal_key, secret)
      cache(root) if root
    rescue Encryption::EncryptionError
      nil
    end

    def clear_personal_key_wrap
      return if record.encrypted_root_personal_key.nil? || record.wraps.size == 1

      was_unlocked = unlocked?
      record.update!(encrypted_root_personal_key: nil)
      remember_fingerprint if was_unlocked
    end

    def rewrap_recovered_root(password)
      root = cached_root
      return if root.nil?

      store_root!(cipher.wrap(root, password))
      root
    end

    # Replaces a root that has no password wrap and nothing else that can open it.
    def replace_dead_root(password, create:)
      return unless create

      SiteKeyRoot.transaction do
        current = SiteKeyRoot.lock.find_by(user_id: user.id)
        next if current.nil? || current.encrypted_root.present? || current.recoverable?

        create_root!(password, replace: current)
      end
    end

    def create_root!(password, replace: nil)
      root = SecureRandom.random_bytes(ROOT_BYTES)
      code = RecoveryCode.generate
      attributes = {
        encrypted_root: cipher.wrap(root, password),
        encrypted_root_personal_key: nil,
        **recovery_code_attributes(root, code),
      }
      if replace
        replace.update!(attributes)
      else
        SiteKeyRoot.transaction(requires_new: true) { SiteKeyRoot.create!(user:, **attributes) }
        user.reload_site_key_root
      end
      user_session[RECOVERY_CODE_SESSION_KEY] = code
      analytics&.site_key_root_created(replaced: replace.present?)
      root
    rescue ActiveRecord::RecordNotUnique
      encrypted_root = user.reload_site_key_root.encrypted_root
      cipher.unwrap(encrypted_root, password) if encrypted_root
    end

    def issue_recovery_code(root)
      code = RecoveryCode.generate
      record.update!(recovery_code_attributes(root, code))
      remember_fingerprint
      user_session[RECOVERY_CODE_SESSION_KEY] = code
    end

    def recovery_code_attributes(root, code)
      {
        encrypted_root_recovery_code: cipher.wrap(root, RecoveryCode.normalize(code)),
        recovery_code_generated_at: Time.zone.now,
        recovery_code_acknowledged_at: nil,
      }
    end

    # A code minted in a session that ended before it was shown is useless; mint another.
    def ensure_recovery_code_shown(root)
      return if record.recovery_code_acknowledged_at.present? || pending_recovery_code.present?

      issue_recovery_code(root)
    end

    def store_wrap!(column, encrypted_root)
      return if encrypted_root.nil? || record.nil?

      record.update!(column => encrypted_root)
      remember_fingerprint
      encrypted_root
    end

    def cache(root)
      user_session[SESSION_KEY] = SessionEncryptor.new.kms_encrypt(Base64.strict_encode64(root))
      remember_fingerprint
      root
    end

    def remember_fingerprint
      user_session[FINGERPRINT_SESSION_KEY] = fingerprint
    end

    def fingerprint
      fingerprint_of(record)
    end

    def fingerprint_of(site_key_root)
      return if site_key_root.nil?

      Digest::SHA256.hexdigest(site_key_root.wraps.sort.flatten.join("\n"))
    end

    def cached_root
      return unless unlocked?

      Base64.strict_decode64(SessionEncryptor.new.kms_decrypt(user_session[SESSION_KEY]))
    end
  end
end
