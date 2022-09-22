# Mock version of AbTestBucket, used to pre-assign items to buckets for deterministic tests
class FakeAbTestBucket
  attr_reader :discriminator_to_bucket

  # @example
  #   FakeAbTestBucket.new('aaa' => :default, 'bbb' => :experiment)
  def initialize(discriminator_to_bucket)
    @discriminator_to_bucket = discriminator_to_bucket
  end

  def bucket(discriminator)
    discriminator_to_bucket.fetch(discriminator, :default)
  end
end
