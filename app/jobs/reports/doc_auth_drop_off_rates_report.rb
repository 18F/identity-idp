require 'identity/hostdata'

module Reports
  class DocAuthDropOffRatesReport < BaseReport
    REPORT_NAME = 'doc-auth-drop-off-rates-report'.freeze

    def perform(_date)
      ret = generate_report
      save_report(REPORT_NAME, ret.join, extension: 'txt')
    end

    private

    def generate_report
      ret = []
      transaction_with_timeout do
        generate_blanket_report_all_sps(ret)
        generate_blanket_reports_per_sp(ret)
        generate_overall_report_all_sps(ret)
        generate_overall_reports_per_sp(ret)
      end
      ret
    end

    def generate_blanket_reports_per_sp(ret)
      ServiceProvider.where(ial: 2).each do |sp|
        generate_blanket_report_per_sp(sp, ret)
      end
    end

    def generate_overall_reports_per_sp(ret)
      ServiceProvider.where(ial: 2).each do |sp|
        generate_overall_report_per_sp(sp, ret)
      end
    end

    def generate_blanket_report_per_sp(sp, ret)
      blanket_drop_off_rates_per_sp_all_time(ret, sp)
      blanket_drop_off_rates_per_sp_last_30_days(ret, sp)
      blanket_drop_off_rates_per_sp_last_24_hours(ret, sp)
    end

    def generate_overall_report_per_sp(sp, ret)
      overall_drop_off_rates_per_sp_all_time(ret, sp)
      overall_drop_off_rates_per_sp_last_30_days(ret, sp)
      overall_drop_off_rates_per_sp_last_24_hours(ret, sp)
    end

    def generate_blanket_report_all_sps(ret)
      blanket_drop_off_rates_all_sps_all_time(ret)
      blanket_drop_off_rates_all_sps_last_30_days(ret)
      blanket_drop_off_rates_all_sps_last_24_hours(ret)
    end

    def generate_overall_report_all_sps(ret)
      overall_drop_off_rates_all_sps_all_time(ret)
      overall_drop_off_rates_all_sps_last_30_days(ret)
      overall_drop_off_rates_all_sps_last_24_hours(ret)
    end

    def overall_drop_off_rates_all_sps_all_time(ret)
      ret << Db::DocAuthLog::OverallDropOffRatesAllSpsAllTime.new.
        call('Overall drop off rates for all SPs all time')
    end

    def overall_drop_off_rates_all_sps_last_24_hours(ret)
      ret << Db::DocAuthLog::OverallDropOffRatesAllSpsInRange.new.
        call('Overall drop off rates for all SPs last 24 hours', Date.yesterday, today)
    end

    def overall_drop_off_rates_all_sps_last_30_days(ret)
      ret << Db::DocAuthLog::OverallDropOffRatesAllSpsInRange.new.
        call('Overall drop off rates for all SPs last 30 days', today - 30.days, today)
    end

    def blanket_drop_off_rates_all_sps_all_time(ret)
      ret << Db::DocAuthLog::BlanketDropOffRatesAllSpsAllTime.new.
        call('Blanket drop off rates for all SPs all time')
    end

    def blanket_drop_off_rates_all_sps_last_24_hours(ret)
      ret << Db::DocAuthLog::BlanketDropOffRatesAllSpsInRange.new.
        call('Blanket drop off rates for all SPs last 24 hours', Date.yesterday, today)
    end

    def blanket_drop_off_rates_all_sps_last_30_days(ret)
      ret << Db::DocAuthLog::BlanketDropOffRatesAllSpsInRange.new.
        call('Blanket drop off rates for all SPs last 30 days', today - 30.days, today)
    end

    def blanket_drop_off_rates_per_sp_all_time(ret, sp)
      ret << Db::DocAuthLog::BlanketDropOffRatesPerSpAllTime.new.
        call('Blanket drop off rates per SP all time', sp.issuer)
    end

    def blanket_drop_off_rates_per_sp_last_24_hours(ret, sp)
      ret << Db::DocAuthLog::BlanketDropOffRatesPerSpInRange.new.
        call('Blanket drop off rates last 24 hours', sp.issuer, Date.yesterday, today)
    end

    def blanket_drop_off_rates_per_sp_last_30_days(ret, sp)
      ret << Db::DocAuthLog::BlanketDropOffRatesPerSpInRange.new.
        call('Blanket drop off rates last 30 days', sp.issuer, today - 30.days, today)
    end

    def overall_drop_off_rates_per_sp_all_time(ret, sp)
      ret << Db::DocAuthLog::OverallDropOffRatesPerSpAllTime.new.
        call('Overall drop off rates per SP all time', sp.issuer)
    end

    def overall_drop_off_rates_per_sp_last_24_hours(ret, sp)
      ret << Db::DocAuthLog::OverallDropOffRatesPerSpInRange.new.
        call('Overall drop off rates last 24 hours', sp.issuer, Date.yesterday, today)
    end

    def overall_drop_off_rates_per_sp_last_30_days(ret, sp)
      ret << Db::DocAuthLog::OverallDropOffRatesPerSpInRange.new.
        call('Overall drop off rates last 30 days', sp.issuer, today - 30.days, today)
    end

    def today
      @today ||= Date.current
    end
  end
end
