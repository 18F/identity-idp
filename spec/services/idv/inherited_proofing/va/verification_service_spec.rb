require 'rails_helper'

RSpec.describe Idv::InheritedProofing::Va::VerificationService do
    include_context 'va_user_context'

    subject { described_class.new(config: LexisNexisFixtures.example_config) }

    describe "valid phone" do
        it "does something" do
            # get a valid call
            expect(subject.verify_phone(valid_user)).to eq "foo"
        end
    end

    describe "invalid phone" do
        it "does something else" do
            # what error messages?
        end
    end
end