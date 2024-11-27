module UspsIppServiceHelper
  def expect_facility_fields_to_be_present(facility)
    expect(facility.address).to be_present
    expect(facility.city).to be_present
    expect(facility.name).to be_present
    expect(facility.saturday_hours).to be_present
    expect(facility.state).to be_present
    expect(facility.sunday_hours).to be_present
    expect(facility.weekday_hours).to be_present
    expect(facility.zip_code_4).to be_present
    expect(facility.zip_code_5).to be_present
  end

  def transliterated_without_change(value)
    UspsInPersonProofing::Transliterator::TransliterationResult.new(
      changed?: false,
      original: value,
      transliterated: value,
      unsupported_chars: [],
    )
  end

  def transliterated(value)
    UspsInPersonProofing::Transliterator::TransliterationResult.new(
      changed?: true,
      original: value,
      transliterated: "transliterated_#{value}",
      unsupported_chars: [],
    )
  end

  def transliterated_with_failure(value)
    UspsInPersonProofing::Transliterator::TransliterationResult.new(
      changed?: true,
      original: value,
      transliterated: "transliterated_failed_#{value}",
      unsupported_chars: [':'],
    )
  end
end
