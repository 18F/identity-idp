class AbTestBucket
  include ActiveModel::Model

  attr_reader :buckets

  validate :within_100_percent

  def initialize(buckets: [{ default: 100 }])
    @buckets = buckets
  end

  def bucket(discriminator: nil)
    return :misconfigured unless valid?
    return :default if discriminator.blank?

    max_sha = (16 ** 64) - 1
    user_value = Digest::SHA256.hexdigest(discriminator).to_i(16).to_f / max_sha * 100

    min = 0
    buckets.each do |bucket|
      max = min + bucket.values.first
      return bucket.keys.first if user_value > min && user_value <= max
      min = max
    end

    :default
  end

  private

  def within_100_percent
    return if buckets_percentage_sum <= 100

    errors.add(
      :buckets,
      'bucket percentages sum is greater than 100',
      type: :ab_test_configuration,
    )
  end

  def buckets_percentage_sum
    buckets.map(&:values).flatten.sum(0)
  end
end
