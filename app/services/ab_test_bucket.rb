class AbTestBucket
  include ActiveModel::Model

  attr_reader :buckets

  validate :within_100_percent

  def initialize(buckets: { default: 100 })
    @buckets = buckets
    raise 'invalid bucket data structure' unless valid_bucket_data_structure?
    ensure_numeric_percentages
  end

  def bucket(discriminator = nil)
    return :misconfigured unless valid?
    return :default if discriminator.blank?

    max_sha = (16 ** 64) - 1
    user_value = Digest::SHA256.hexdigest(discriminator).to_i(16).to_f / max_sha * 100

    min = 0
    buckets.keys.each do |key|
      max = min + buckets[key]
      return key if user_value > min && user_value <= max
      min = max
    end

    :default
  end

  private

  def valid_bucket_data_structure?
    hash_bucket = buckets.is_a?(Hash)
    simple_values = true
    if hash_bucket
      buckets.values.each do |v|
        next unless v.is_a?(Hash) || v.is_a?(Array)
        simple_values = false
      end
    end

    hash_bucket && simple_values
  end

  def ensure_numeric_percentages
    buckets.keys.each do |key|
      buckets[key] = buckets[key].to_f if buckets[key].is_a?(String)
    end
  end

  def within_100_percent
    return if valid_bucket_data_structure? && buckets.values.sum <= 100

    errors.add(
      :buckets,
      'bucket percentages sum is greater than 100',
      type: :ab_test_configuration,
    )
  end
end
