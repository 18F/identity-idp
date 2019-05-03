class JobRun < ApplicationRecord
  validates :pid, presence: true
end
