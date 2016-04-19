class SecurityQuestion < ActiveRecord::Base
  has_many :security_answers

  validates :question, presence: true, uniqueness: true
end
