# See https://www.rfc-editor.org/rfc/rfc4648#section-8
class Base16
  def self.encode16(str)
    output = ''
    str.bytes.each do |char|
      output << char.to_s(16).upcase.rjust(2, "0")
    end
    output
  end

  def self.decode16(str)
    output = ''
    str.chars.each_slice(2) do |chars|
      output << chars.join.to_i(16).chr
    end
    output
  end
end
