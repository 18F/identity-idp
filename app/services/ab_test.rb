class AbTest
  def initialize(key, percent_on)
    @key = key
    @percent_on = percent_on.to_s.to_i
  end

  def enabled?(session, reset)
    return false if @percent_on.zero?
    return true if @percent_on == 100
    return session[@key] if !reset && session.key?(@key)
    session[@key] = (@percent_on < SecureRandom.random_number(100))
  end
end
