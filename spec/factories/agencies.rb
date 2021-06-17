FactoryBot.define do
  factory :agency do
    agency_name_templates = [
      'Department of %{industry} %{tag}',
      'Bureau of %{industry} %{tag}',
      '%{industry} Administration %{tag}',
      '%{industry} Agency %{tag}',
    ]

    id { Agency.last&.id.to_i + 1 } # autoincrementer is messed up for this table
    name do
      format(
        agency_name_templates.sample,
        industry: Faker::Company.industry,
        tag: SecureRandom.hex,
      )
    end
    abbreviation do
      name.
        split(' ').
        map { |w| w[0].upcase }.
        select { |c| /\w/.match?(c) }.
        join + id.to_s
    end
  end
end
