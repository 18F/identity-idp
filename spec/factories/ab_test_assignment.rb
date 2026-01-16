FactoryBot.define do
  factory :ab_test_assignment do
    ab_test = AbTests.all.values.sample

    experiment { ab_test.experiment }
    discriminator { Random.uuid }
    bucket { [*ab_test.buckets.keys, ab_test.default_bucket].sample }
  end
end
