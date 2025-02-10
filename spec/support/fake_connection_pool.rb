# The real ConnectionPools persist clients across specs which
# makes stubbing via the Aws.config unreliable, so we use this to help mock
# specific objects
class FakeConnectionPool
  def initialize(&block)
    @block = block
  end

  def with
    yield @block.call
  end
end
