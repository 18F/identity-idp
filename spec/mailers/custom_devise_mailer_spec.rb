require 'rails_helper'

describe CustomDeviseMailer do
  let(:user) { build_stubbed(:user) }

  describe '#confirmation_instructions' do
    let(:mail) { CustomDeviseMailer.confirmation_instructions(user, '123ABC') }

    it_behaves_like 'a system email'
  end
end
