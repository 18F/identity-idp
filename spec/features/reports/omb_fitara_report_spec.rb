require 'rails_helper'

feature 'OMB Fitara compliance officer runs report' do
  it 'works in july' do
    Timecop.travel Date.new(2019, 7, 2) do
      visit sign_up_email_path
      sign_up_and_2fa_loa1_user

      results = '{"counts":[{"month":"201907","count":1},{"month":"201906","count":0}]}'
      expect(Reports::OmbFitaraReport.new.call).to eq(results)
    end
  end

  it 'works in december' do
    Timecop.travel Date.new(2019, 12, 2) do
      visit sign_up_email_path
      sign_up_and_2fa_loa1_user

      results = '{"counts":[{"month":"201912","count":1},{"month":"201911","count":0}]}'
      expect(Reports::OmbFitaraReport.new.call).to eq(results)
    end
  end

  it 'works in january' do
    Timecop.travel Date.new(2019, 1, 2) do
      visit sign_up_email_path
      sign_up_and_2fa_loa1_user

      results = '{"counts":[{"month":"201901","count":1},{"month":"201812","count":0}]}'
      expect(Reports::OmbFitaraReport.new.call).to eq(results)
    end
  end

  describe '.generate_s3_paths' do
    let(:report_name) { 'omb-fitara-report' }

    it 'generates paths with date or latest prefix' do
      expect(LoginGov::Hostdata).to receive(:env).and_return('ci')

      Timecop.travel Date.new(2018, 1, 2) do
        expect(Reports::OmbFitaraReport.new.send(:generate_s3_paths, report_name)).
          to eq(['ci/omb-fitara-report/latest.omb-fitara-report.json',
                 'ci/omb-fitara-report/2018/2018-01-02.omb-fitara-report.json'])
      end
    end
  end
end
