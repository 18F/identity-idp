# Use this class to store a plain Struct in redis. It will be stored
# encrypted and by default will expire, the struct must have a +redis_key_prefix+
# class method
#
# @example
#   MyStruct = Struct.new(:id, :a, :b) do
#     def self.redis_key_prefix
#       'mystruct'
#     end
#   end
#
#   struct = MyStruct.new('id123', 'a', 'b')
#
#   EncryptedRedisStructStorage.store(struct)
#   s = EncryptedRedisStructStorage.load('id123', type: MyStruct)
module EncryptedRedisStructStorage
  module_function

  def load(id, type:)
    check_for_id_property!(type)

    ciphertext = REDIS_POOL.with { |client| client.read(key(id, type: type)) }
    return nil if ciphertext.blank?

    json = Encryption::Encryptors::SessionEncryptor.new.decrypt(ciphertext)
    data = JSON.parse(json).with_indifferent_access
    type.new.tap do |struct|
      struct.id = id
      init_fields(struct: struct, data: data)
    end
  end

  def store(struct, expires_in: 60)
    check_for_id_property!(struct.class)
    check_for_empty_id!(struct.id)

    payload = struct.as_json
    payload.delete('id')

    REDIS_POOL.with do |client|
      client.write(
        key(struct.id, type: struct.class),
        Encryption::Encryptors::SessionEncryptor.new.encrypt(payload.to_json),
        expires_in: expires_in,
      )
    end
  end

  def key(id, type:)
    if type.respond_to?(:redis_key_prefix)
      [type.redis_key_prefix, id].join(':')
    else
      raise "#{self} expected #{type.name} to have defined class method redis_key_prefix"
    end
  end

  # Assigns member fields from a hash. That way, it doesn't matter
  # if a Struct was created with keyword_init or not (and we can't currently
  # reflect on that field)
  # @param [Hash] data
  def init_fields(struct:, data:)
    data.each do |key, value|
      struct[key] = value
    end
  end

  def check_for_id_property!(type)
    return if type.members.include?(:id)
    raise "#{self} expected #{type.name} to have an id property"
  end

  def check_for_empty_id!(id)
    raise ArgumentError, 'id cannot be empty' if id.blank?
  end
end
