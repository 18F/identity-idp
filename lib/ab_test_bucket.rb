class AbTestBucket
  attr_reader :buckets, :experiment_name

  def initialize(experiment_name:, buckets: {})
    @buckets = buckets
    @experiment_name = experiment_name
    raise 'invalid bucket data structure' unless valid_bucket_data_structure?
    ensure_numeric_percentages
    raise 'bucket percentages exceed 100' unless within_100_percent?
  end

  def bucket(discriminator = nil)
    return :default if discriminator.blank?

    user_value = percent(discriminator)

    min = 0
    buckets.keys.each do |key|
      max = min + buckets[key]
      return key if user_value > min && user_value <= max
      min = max
    end

    :default
  end

  private

  def percent(discriminator)
    max_sha = (16 ** 64) - 1
    Digest::SHA256.hexdigest("#{discriminator}:#{experiment_name}").to_i(16).to_f / max_sha * 100
  end

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

  def within_100_percent?
    valid_bucket_data_structure? && buckets.values.sum <= 100
  end
end
