class Base16

  # The IRS has requested data be encoded this way. Loosely emulate the Base64 class.

  def self.encode16(str)
    str.bytes.map { |char| char.to_s(16).upcase.rjust(2, "0") }.join
  end

  def self.decode16(str)
    output = ''
    str.chars.each_slice(2) do |chars|
      output << chars.join.to_i(16).chr
    end
    output
  end
end
