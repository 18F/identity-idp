# Mock version of AbTestBucket, used to pre-assign items to buckets for deterministic tests
class FakeAbTestBucket
  attr_reader :discriminator_to_bucket, :all_result

  def initialize
    @discriminator_to_bucket = {}
  end

  def bucket(discriminator)
    all_result || discriminator_to_bucket.fetch(discriminator, :default)
  end

  # @example
  #   ab.assign('aaa' => :default, 'bbb' => :experiment)
  def assign(discriminator_to_bucket)
    @discriminator_to_bucket.merge!(discriminator_to_bucket)
  end

  def assign_all(bucket)
    @all_result = bucket
  end
end
