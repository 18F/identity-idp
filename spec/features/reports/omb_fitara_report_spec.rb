require 'rails_helper'

feature 'OMB Fitara compliance officer runs report' do
  it 'works in july' do
    travel_to(Date.new(2019, 7, 2)) do
      visit sign_up_email_path
      sign_up_and_2fa_ial1_user

      results = '{"counts":[{"month":"201907","count":1},{"month":"201906","count":0}]}'
      expect(Reports::OmbFitaraReport.new.perform(Time.zone.today)).to eq(results)
    end
  end

  it 'works in december' do
    travel_to(Date.new(2019, 12, 2)) do
      visit sign_up_email_path
      sign_up_and_2fa_ial1_user

      results = '{"counts":[{"month":"201912","count":1},{"month":"201911","count":0}]}'
      expect(Reports::OmbFitaraReport.new.perform(Time.zone.today)).to eq(results)
    end
  end

  it 'works in january' do
    travel_to(Date.new(2019, 1, 2)) do
      visit sign_up_email_path
      sign_up_and_2fa_ial1_user

      results = '{"counts":[{"month":"201901","count":1},{"month":"201812","count":0}]}'
      expect(Reports::OmbFitaraReport.new.perform(Time.zone.today)).to eq(results)
    end
  end

  describe '.generate_s3_paths' do
    let(:report_name) { 'omb-fitara-report' }

    it 'generates paths with date or latest prefix' do
      expect(Identity::Hostdata).to receive(:env).and_return('ci')

      travel_to(Date.new(2018, 1, 2)) do
        expect(Reports::OmbFitaraReport.new.send(:generate_s3_paths, report_name, 'json')).
          to eq(
            ['ci/omb-fitara-report/latest.omb-fitara-report.json',
             'ci/omb-fitara-report/2018/2018-01-02.omb-fitara-report.json'],
          )
      end
    end
  end
end
