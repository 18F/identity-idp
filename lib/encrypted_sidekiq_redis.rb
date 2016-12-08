require 'redis'
require 'gibberish'

class EncryptedSidekiqRedis
  attr_accessor :redis, :cipher

  def initialize(opts)
    self.redis = Redis.new(opts)
    self.cipher = Gibberish::AES.new(Figaro.env.session_encryption_key)
  end

  def lpush(key, value)
    super(key, encrypt_job(value))
  end

  def rpush(key, value)
    super(key, encrypt_job(value))
  end

  def lpop(key)
    decrypt_job(super(key))
  end

  def rpop(key)
    decrypt_job(super(key))
  end

  def blpop(*args)
    queue, job = super(args)
    [queue, decrypt_job(job)]
  end

  def brpop(*args)
    queue, job = super(args)
    [queue, decrypt_job(job)]
  end

  def zadd(key, *args)
    ts, job = args
    super(key, [ts, encrypt_job(job)])
  end

  def zrem(key, member)
    # member must be removed from redis as-is (encrypted)
    # but it is used elsewhere as if it was decrypted, so alter it in place.
    ret = super(key, member)
    if ret
      decrypted_job = decrypt_job(member)
      member.clear
      member << decrypted_job
    end
    ret
  end

  # rubocop:disable Style/MethodMissing
  def method_missing(meth, *args, &block)
    redis.send(meth, *args, &block)
  end
  # rubocop:enable Style/MethodMissing

  def respond_to_missing?(meth, include_private)
    redis.respond_to?(meth, include_private)
  end

  private

  def decrypt_job(job_json)
    # if job is JSON, possibly ActiveJob format, possibly Gibberish format.
    begin
      job = JSON.parse(job_json)
    rescue
      return job_json
    end
    if encrypted?(job)
      cipher.decrypt(job_json)
    else
      job_json
    end
  end

  def encrypt_job(plain_job)
    if plain_job.is_a?(Array)
      plain_job.map { |job| encrypt_job(job) }
    else
      encrypted?(plain_job) ? plain_job : cipher.encrypt(plain_job)
    end
  end

  def encrypted?(job)
    return true if job.is_a?(Hash) && job.key?('cipher')
    return true if job.is_a?(String) && job =~ /"cipher"/
    false
  end
end
