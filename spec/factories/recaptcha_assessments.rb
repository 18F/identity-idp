FactoryBot.define do
  factory :recaptcha_assessment do
    id { "projects/0000000000/assessments/#{Random.hex(8)}" }
    annotation_reason { 'INITIATED_TWO_FACTOR' }
  end
end
