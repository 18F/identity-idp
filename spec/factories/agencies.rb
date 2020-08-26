FactoryBot.define do
  factory :agency do
    agency_name_templates = [
      'Department of %{industry}',
      'Bureau of %{industry}',
      '%{industry} Administration',
      '%{industry} Agency',
    ]

    id { Agency.last&.id.to_i + 1 } # autoincrementer is messed up for this table
    name { format(agency_name_templates.sample, industry: Faker::Company.industry) }
  end
end
