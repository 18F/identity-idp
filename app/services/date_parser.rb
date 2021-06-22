module DateParser
  AMERICAN_REGEX = %r{(?<month>\d{1,2})/(?<day>\d{1,2})/(?<year>\d{4})}.freeze

  # Date parsing with a fallback for american-style Month/Day/Year
  # since we have legacy data in PII bundles that may be stored this way
  def self.parse(str, allow_american: true)
    if allow_american && (m = str.match(AMERICAN_REGEX))
      Date.parse("#{m[:year]}-#{m[:month]}-#{m[:day]}")
    else
      Date.parse(str)
    end
  end
end
