require 'rails_helper'

describe Reports::DeletedUserAccountsReport do
  subject { described_class.new }

  it 'is completes without error' do
    subject.call
  end
end
