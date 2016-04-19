# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  factory :second_factor do
    trait :email do
      name 'Email'
    end

    trait :mobile do
      name 'Mobile'
    end
  end
end
