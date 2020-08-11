class DocumentCaptureSessionResult
  REDIS_KEY_PREFIX = 'dcs:result'.freeze

  attr_reader :id, :success, :pii

  alias success? success
  alias pii_from_doc pii

  class << self
    def load(id)
      ciphertext = REDIS_POOL.with { |client| client.read(key(id)) }
      return nil if ciphertext.blank?
      decrypt_and_deserialize(id, ciphertext)
    end

    def key(id)
      [REDIS_KEY_PREFIX, id].join(':')
    end

    private

    def decrypt_and_deserialize(id, ciphertext)
      deserialize(
        id,
        Encryption::Encryptors::SessionEncryptor.new.decrypt(ciphertext),
      )
    end

    def deserialize(id, json)
      data = JSON.parse(json)
      new(
        id: id,
        success: data['success'],
        pii: data['pii'],
      )
    end
  end

  def initialize(id:, success:, pii:)
    @id = id
    @success = success
    @pii = pii
  end

  def unload
    REDIS_POOL.with do |client|
      client.write(self.class.key(id), serialize_and_encrypt, expires_in: 60)
    end
  end

  private

  def serialize_and_encrypt
    Encryption::Encryptors::SessionEncryptor.new.encrypt(serialize)
  end

  def serialize
    {
      success: success,
      pii: pii,
    }.to_json
  end
end
