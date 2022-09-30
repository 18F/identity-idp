module DateParser
  AMERICAN_REGEX = %r{(?<month>\d{1,2})/(?<day>\d{1,2})/(?<year>\d{4})}

  # Date parsing with a fallback for american-style Month/Day/Year
  # since we have legacy data in PII bundles that may be stored this way
  # @param [String,Date] val
  def self.parse_legacy(val)
    return val if val.is_a?(Date)

    if (m = val.match(AMERICAN_REGEX))
      Date.parse("#{m[:year]}-#{m[:month]}-#{m[:day]}")
    else
      Date.parse(val)
    end
  end
end
