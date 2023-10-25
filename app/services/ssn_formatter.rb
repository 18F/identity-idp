# frozen_string_literal: true

module SsnFormatter
  def self.format(ssn)
    normalized_ssn = normalize(ssn)
    "#{normalized_ssn[0..2]}-#{normalized_ssn[3..4]}-#{normalized_ssn[5..8]}"
  end

  def self.format_masked(ssn)
    normalized_ssn = normalize(ssn)
    "#{normalized_ssn[0]}**-**-***#{normalized_ssn[-1]}"
  end

  def self.normalize(ssn)
    ssn.to_s.gsub(/\D/, '')[0..8]
  end
end
