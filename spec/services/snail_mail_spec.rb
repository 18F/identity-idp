require 'rails_helper'

describe SnailMail do
  describe '#daily_job_executed' do
    it 'no jobs have executed today' do
      snail_mail = SnailMail.new
      result = snail_mail.daily_job_executed?
    end
  end
end
