# Take the proccessed alerts and reformat them in a hash so that its easier to search and collect
# stats through cloudwatch.

require 'rails_helper'

RSpec.describe DocAuth::ProcessedAlertToLogAlertFormatter do
  let(:alerts) do
    { passed: [{ alert: 'Alert_1', name: 'Visible Pattern', result: 'Passed' }],
      failed:
       [
         { alert: 'Alert_1', name: '2D Barcode Read', result: 'Failed' },
         { alert: 'Alert_2', name: 'Layout Valid', result: 'Attention' },
         { alert: 'Alert_3', name: '2D Barcode Read', result: 'Failed' },
         { alert: 'Alert_4', name: 'Visible Pattern', result: 'Failed' },
         { alert: 'Alert_5', name: 'Visible Photo Characteristics', result: 'Failed' },
       ] }
  end

  context('when ProcessedAlertToLogAlertFormatter is called') do
    subject {
      DocAuth::ProcessedAlertToLogAlertFormatter.new.log_alerts(alerts)
    }

    it('returns failed if both passed and failed are returned by the alert') do
      expect(subject).to match(a_hash_including(visible_pattern: { no_side: 'Failed' }))
    end

    it('returns the formatted log hash') do
      expect(subject).to eq(
        { '2d_barcode_read': { no_side: 'Failed' },
          layout_valid: { no_side: 'Attention' },
          visible_pattern: { no_side: 'Failed' },
          visible_photo_characteristics: { no_side: 'Failed' } },
      )
    end
  end
end
