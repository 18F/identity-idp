class ChangePhoneEvent < ApplicationRecord
  EVENT_REQUEST = 1
  EVENT_CANCEL = 2
  EVENT_GRANT = 3
  EVENT_ANSWER_CORRECT = 4
  EVENT_ANSWER_WRONG = 5
  EVENT_COMPLETE = 6
  EVENT_REPORT_FRAUD = 7
  belongs_to :user
end
