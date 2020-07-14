require 'login_gov/hostdata'

module Reports
  class DocAuthDropOffRatesReport < BaseReport
    REPORT_NAME = 'doc-auth-drop-off-rates-report'.freeze

    def call
      ret = generate_report
      save_report(REPORT_NAME, ret.join)
    end

    private

    def generate_report
      ret = []
      generate_per_sp_reports(ret)
      per_sp_report(ret)
      ret
    end

    def generate_per_sp_reports(ret)
      ServiceProvider.where(ial: 2).each do |sp|
        transaction_with_timeout do
          generate_per_sp_report(sp, ret)
        end
      end
    end

    def generate_per_sp_report(sp, ret)
      ret << Db::DocAuthLog::BlanketDropOffRatesPerSpAllTime.new.
             call('Drop off rates per SP all time', sp.issuer)
      ret << Db::DocAuthLog::BlanketDropOffRatesPerSpInRange.new.
             call('Drop off rates last 24 hours', sp.issuer, Date.yesterday, today)
      ret << Db::DocAuthLog::BlanketDropOffRatesPerSpInRange.new.
             call('Drop off rates last 30 days', sp.issuer, today - 30.days, today)
    end

    def all_sps_report(ret)
      transaction_with_timeout do
        ret << Db::DocAuthLog::BlanketDropOffRatesAllSpsAllTime.new.
               call('Drop off rates for all SPs all time')
        ret << Db::DocAuthLog::BlanketDropOffRatesAllSpsInRange.new.
               call('Drop off rates for all SPs last 24 hours', Date.yesterday, today)
        ret << Db::DocAuthLog::BlanketDropOffRatesAllSpsInRange.new.
               call('Drop off rates for all SPs last 30 days', today - 30.days, today)
      end
    end

    def today
      @today ||= Date.current
    end
  end
end
