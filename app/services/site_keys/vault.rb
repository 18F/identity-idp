# frozen_string_literal: true

module SiteKeys
  # Unlocks a user's site key root with their password and keeps it KMS-encrypted in the
  # session, alongside a fingerprint of the stored wrap so the session re-locks when another
  # session changes it.
  class Vault
    SESSION_KEY = :encrypted_site_key_root
    FINGERPRINT_SESSION_KEY = :site_key_root_fingerprint
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
    # is set, so users who never sign in to a site key SP never get one.
    # @return [String, nil] the root
    # @raise [RootMismatchError, Encryption::EncryptionError]
    def unlock(password, create: false)
      return unless enabled?

      root = if record
               cipher.unwrap(record.encrypted_root, password)
             elsif create
               create_root!(password)
             end
      cache(root) if root
      root
    end

    # Replaces the root whose stored wrap had `expected_fingerprint`; does nothing when another
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

    # @return [String, nil] nil while the root is locked in this session
    def wrap_cached_root(new_password)
      root = cached_root
      cipher.wrap(root, new_password) if root
    end

    def store_root!(encrypted_root)
      return if encrypted_root.nil? || record.nil?

      record.update!(encrypted_root:)
      remember_fingerprint
      encrypted_root
    end

    # Stores a root re-wrapped by `wrap_cached_root`, or deletes the root when it could not be
    # re-wrapped (locked in this session, or changed by another session since), so a password
    # change never leaves a root wrapped under a password the user no longer has. Call inside
    # the transaction that changes the password.
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

    def unlocked?
      user_session[SESSION_KEY].present? &&
        user_session[FINGERPRINT_SESSION_KEY].present? &&
        user_session[FINGERPRINT_SESSION_KEY] == fingerprint
    end

    # The password would unlock the root but has not been entered in this session.
    def locked?
      enabled? && record.present? && !unlocked?
    end

    def needs_password?
      locked? && !unavailable?
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
    # @return [Symbol] :ready, :needs_password or :unavailable
    def status
      return :ready if unlocked?
      return :unavailable if unavailable?

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

    def create_root!(password, replace: nil)
      root = SecureRandom.random_bytes(ROOT_BYTES)
      replaced = replace.present?
      encrypted_root = cipher.wrap(root, password)
      if replaced
        replace.update!(encrypted_root:)
      else
        SiteKeyRoot.transaction(requires_new: true) { SiteKeyRoot.create!(user:, encrypted_root:) }
        user.reload_site_key_root
      end
      analytics&.site_key_root_created(replaced:)
      root
    rescue ActiveRecord::RecordNotUnique
      cipher.unwrap(user.reload_site_key_root.encrypted_root, password)
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
      Digest::SHA256.hexdigest(site_key_root.encrypted_root) if site_key_root
    end

    def cached_root
      return unless unlocked?

      Base64.strict_decode64(SessionEncryptor.new.kms_decrypt(user_session[SESSION_KEY]))
    end
  end
end
