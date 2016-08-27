require 'rails_helper'

describe UpdateUserPhoneForm do
  let(:user) { build_stubbed(:user, :signed_up) }
  subject { UpdateUserPhoneForm.new(user) }

  it_behaves_like 'a phone form'
end
