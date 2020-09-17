# Include this mixin in a plain Struct to add ability to store it in redis
# Call +configure_encrypted_redis_struct+ with configuration values
#
# @example
#   MyStruct = Struct.new(:id, :a, :b) do
#     include EncryptedRedisStructStorage
#     configure_encrypted_redis_struct key_prefix: 'myprefix'
#   end
#
#   MyStruct.store(id: '123', a: 'a', 'b')
#   s = MyStruct.load('123')
module EncryptedRedisStructStorage
  def self.included(klass)
    if klass.members.include?(:id)
      klass.extend ClassMethods
    else
      raise 'EncryptedRedisStructStorage can only be included in classes that have an id key'
    end
  end

  # Assigns member fields from a hash. That way, it doesn't matter
  # if a Struct was created with keyword_init or not (and we can't currently
  # reflect on that field)
  # @param [Hash] values
  def init_fields(values)
    values.each do |key, value|
      self[key] = value
    end
  end

  module ClassMethods
    attr_reader :expires_in

    def configure_encrypted_redis_struct(key_prefix:, expires_in: 60)
      @redis_key_prefix = key_prefix.dup.freeze
      @expires_in = expires_in
    end

    def load(id)
      ciphertext = REDIS_POOL.with { |client| client.read(key(id)) }
      return nil if ciphertext.blank?
      decrypt_and_deserialize(id, ciphertext)
    end

    def store(id:, **rest)
      result = new.tap do |struct|
        struct.id = id
        struct.init_fields(rest)
      end

      REDIS_POOL.with do |client|
        payload = result.as_json
        payload.delete('id')

        client.write(
          key(id),
          Encryption::Encryptors::SessionEncryptor.new.encrypt(payload.to_json),
          expires_in: self.expires_in,
        )
      end
    end

    def key(id)
      [self.redis_key_prefix, id].join(':')
    end

    def redis_key_prefix
      return @redis_key_prefix if @redis_key_prefix.present?
      raise "#{self.name} no redis_key_prefix! make sure to call configure_encrypted_redis_struct"
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
      new.tap do |struct|
        struct.id = id
        struct.init_fields(data)
      end
    end
  end
end
