# frozen_string_literal: true

module SiteKeys
  # Opens a person's site key with their password and keeps the private scalar KMS-encrypted in
  # the session, beside a fingerprint of the stored wrap so this session treats the key as locked
  # again when another session rewraps or deletes it.
  class Vault
    SESSION_KEY = :encrypted_site_key
    FINGERPRINT_SESSION_KEY = :site_key_fingerprint
    UNAVAILABLE_SESSION_KEY = :site_key_unavailable

    attr_reader :user, :user_session

    def initialize(user:, user_session:, analytics: nil)
      @user = user
      @user_session = user_session
      @analytics = analytics
    end

    # Opens the key with the password just entered. A key is created only when `create` is set,
    # so a person who never signs in to a listed client never gets one.
    # @return [String, nil] the private scalar
    # @raise [MismatchError, Encryption::EncryptionError]
    def unlock(password, create: false)
      private_key = if record&.encrypted_private_key
                      cipher.unwrap(record.encrypted_private_key, password)
                    elsif record.nil? && create
                      create!(password)
                    end
      cache(private_key) if private_key
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
    # @return [Symbol] :ready, :needs_password or :unavailable
    def status
      return :ready if unlocked?
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

    def fingerprint_of(site_key)
      Digest::SHA256.hexdigest(site_key.encrypted_private_key.to_s) if site_key
    end

    def cached_private_key
      return unless unlocked?

      Base64.strict_decode64(SessionEncryptor.new.kms_decrypt(user_session[SESSION_KEY]))
    end
  end
end
