require 'rails_helper'

describe RegisterUserEmailForm do
  subject { RegisterUserEmailForm.new }

  it_behaves_like 'email validation'
end
