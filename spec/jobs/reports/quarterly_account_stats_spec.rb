require 'rails_helper'
require 'csv'

RSpec.describe Reports::QuarterlyAccountStats do
  let(:report_date) { Date.new(2020, 1, 1) }

    subject(:report) { described_class.new.tap { |r| r.report_date = report_date } }

  describe '#perform' do
    # TK
  end

  describe '#report_body' do
    # subject(:report_body) { report.report_body }

    let(:proofed_user_now) { create(:user, :proofed) }
    let(:base_user) { create(:user) }
    let(:deleted_user) do
      user = create(:user)
      DeletedUser.create_from_user(user)
      # Can we make create_from_user return the new object???
      DeletedUser.last
    end

    it 'does a thing' do
      # temp scaffolding to make sure I set this up right
      expect(deleted_user.deleted_at).not_to be_nil
    end

    # Create some accounts: active, deleted, proofed
    # now, 1 month ago, 6 months ago
  end
end
