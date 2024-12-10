RSpec::Matchers.define :match_xml do |comparison|
  diffable

  # REXML::Documents do not implement comparison; they are never ==.
  # This matcher considers the documents the same if their string outputs
  # are equal after both going through the REXML::Formatters::Pretty.
  match do |document|
    # We have to override these for the diff to use these, rather than input strings
    @actual = XmlHelper.pretty_xml_from_string(document)
    @expected = XmlHelper.pretty_xml_from_string(comparison)

    expect(@actual).to eq(@expected)
  end

  failure_message do
    'Expected XML documents to be the same, but they differed:'
  end
end
