FactoryGirl.define do
  factory :security_question do
    question 'Where is Waldo?'
    active true

    factory :security_question_2 do
      question 'Bueller?'
      active true
    end

    factory :security_question_3 do
      question 'Who is your favorite superhero?'
      active false
    end

    factory :security_question_4 do
      question 'How high can your magic carpet fly?'
      active true
    end

    factory :security_question_5 do
      question 'Where did Oliver Queen learn archery?'
      active true
    end

    factory :security_question_6 do
      question 'What is the meaning of life?'
      active true
    end

    factory :security_question_7 do
      question 'Why is the sky blue?'
      active true
    end

    factory :security_question_8 do
      question 'Are we there yet?'
      active false
    end
  end
end
