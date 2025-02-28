# frozen_string_literal: true

class RecaptchaAssessment < ApplicationRecord
  enum :annotation, {
    legitimate: 'LEGITIMATE',
    fraudulent: 'FRAUDULENT',
  }

  enum :annotation_reason, {
    initiated_two_factor: 'INITIATED_TWO_FACTOR',
    passed_two_factor: 'PASSED_TWO_FACTOR',
    failed_two_factor: 'FAILED_TWO_FACTOR',
  }
end
