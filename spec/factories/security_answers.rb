FactoryGirl.define do
  factory :security_answer do
    text 'My answer'
    security_question_id 1
    user_id 1
  end
end
