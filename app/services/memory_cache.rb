class MemoryCache
  @@cache = ActiveSupport::Cache::MemoryStore.new

  def self.cache
    @@cache
  end
end
