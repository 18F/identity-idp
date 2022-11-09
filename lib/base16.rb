# See https://www.rfc-editor.org/rfc/rfc4648#section-8
class Base16
  def self.encode16(str)
    str.unpack1('H*').tap(&:upcase!)
  end

  def self.decode16(str)
    [str].pack('H*')
  end
end
