class IdentitySession
  def initialize(data)
    @data = data
  end

  def [](key)
    @data[key]
  end

  def []=(key, value)
    @data[key] = value
  end

  def stringify_keys
    @data.stringify_keys
  end

  def dig(*args)
    @data.dig(*args)
  end
end

