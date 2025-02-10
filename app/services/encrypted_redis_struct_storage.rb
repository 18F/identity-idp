# frozen_string_literal: true

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

    ciphertext = REDIS_POOL.with { |client| client.get(key(id, type: type)) }
    return nil if ciphertext.blank?

    json = Encryption::Encryptors::BackgroundProofingArgEncryptor.new.decrypt(ciphertext)
    data = JSON.parse(json, symbolize_names: true)
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

    utf_8_encode_strs = proc do |value|
      if value.is_a?(String)
        value.dup.force_encoding('UTF-8')
      elsif value.is_a?(Array)
        value.map(&utf_8_encode_strs)
      elsif value.is_a?(Hash)
        value.transform_values!(&utf_8_encode_strs)
      else
        value
      end
    end

    payload.transform_values!(&utf_8_encode_strs)

    struct_key = key(struct.id, type: struct.class)
    ciphertext = Encryption::Encryptors::BackgroundProofingArgEncryptor.new.encrypt(payload.to_json)

    REDIS_POOL.with do |client|
      client.setex(struct_key, expires_in, ciphertext)
    end
  end

  def key(id, type:)
    if type.respond_to?(:redis_key_prefix)
      return ['redis-pool', type.redis_key_prefix, id].join(':')
    else
      raise "#{self} expected #{type.name} to have defined class method redis_key_prefix"
    end
  end

  # Assigns member fields from a hash. That way, it doesn't matter
  # if a Struct was created with keyword_init or not (and we can't currently
  # reflect on that field)
  # @param [Struct] struct
  # @param [Hash] data
  def init_fields(struct:, data:)
    data.slice(*struct.members).each do |key, value|
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
