describe SecurityQuestion do
  it { is_expected.to have_many(:security_answers) }
  it { is_expected.to validate_presence_of(:question) }
  it { is_expected.to validate_uniqueness_of(:question) }
end
