require 'rails_helper'

RSpec.describe SpReturnLogBillingAdjustment do
  let(:sign_in_row) { create(:sp_return_log, ial: 2, issuer: 'sp', billable: true) }
  let(:delegated_row) do
    create(:sp_return_log, ial: 2, issuer: 'agency', billable: true, access_type: 'delegated')
  end

  it 'records an exclusion of the sign-in row pointing at the delegated row' do
    adjustment = described_class.create!(
      sp_return_log: sign_in_row, adjustment_type: :exclude_from_billing,
      delegated_return_log: delegated_row, resolved_via: :cache
    )

    expect(adjustment).to be_exclude_from_billing
    expect(adjustment).to be_resolved_via_cache
    expect(sign_in_row.excluded_from_billing?).to eq(true)
    expect(delegated_row.excluded_from_billing?).to eq(false)
  end

  it 'is append-only' do
    adjustment = described_class.create!(
      sp_return_log: delegated_row, adjustment_type: :delegated_token_issued,
    )

    expect { adjustment.update!(adjustment_type: :exclude_from_billing) }
      .to raise_error(ActiveRecord::ReadOnlyRecord)
    expect { adjustment.destroy! }.to raise_error(ActiveRecord::ReadOnlyRecord)
    expect(adjustment.reload).to be_delegated_token_issued
  end

  it 'requires an adjustment type' do
    expect { described_class.create!(sp_return_log: sign_in_row) }
      .to raise_error(ActiveRecord::RecordInvalid)
  end
end
