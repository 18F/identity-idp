module SsnFormatter
  def self.format(ssn, mask: false)
    normalized_ssn = ssn.to_s.gsub(/\D/, '')[0..8]

    if mask
      "#{normalized_ssn[0]}**-**-***#{normalized_ssn[-1]}"
    else
      "#{normalized_ssn[0..2]}-#{normalized_ssn[3..4]}-#{normalized_ssn[5..8]}"
    end
  end
end
