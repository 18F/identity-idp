class ProofingDocumentCaptureSessionResult
  REDIS_KEY_PREFIX = 'dcs-proofing:result'.freeze

  attr_reader :id, :pii, :result

  class << self
    def load(id)
      ciphertext = REDIS_POOL.with { |client| client.read(key(id)) }
      return nil if ciphertext.blank?
      decrypt_and_deserialize(id, ciphertext)
    end

    def store(id:, pii:, result:)
      result = new(id: id, pii: pii, result: result)
      REDIS_POOL.with do |client|
        client.write(key(id), result.serialize_and_encrypt, expires_in: 60)
      end
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
        pii: data['pii'],
        result: data['result'],
      )
    end
  end

  def initialize(id:, pii:, result:)
    @id = id
    @pii = pii
    @result = result
  end

  def serialize
    {
      pii: pii,
      result: result,
    }.to_json
  end

  def serialize_and_encrypt
    Encryption::Encryptors::SessionEncryptor.new.encrypt(serialize)
  end
end
