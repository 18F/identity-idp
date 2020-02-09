require 'prawn'
require 'json'
require 'erb'
require 'yaml'
require 'login_gov/hostdata'
require 'squid'
require 'prawn-svg'

module Reports
  class BillingReport
    TOTAL_PRIOR_MONTHS = 4
    LOGO_FN = 'app/assets/images/login-primary@2x.png'.freeze

    def initialize
      @issuer_year_month_to_count = {}
    end

    def call(dest_dir:, year:, month:, auths_json:, sp_yml:)
      @issuer_year_month_to_count = parse_total_monthly_auths_json(auths_json)
      service_providers(sp_yml).each do |sp_issuer_n_hash|
        generate_billing_report(dest_dir, sp_issuer_n_hash, year, month)
      end
    end

    private

    def generate_billing_report(dir, sp_issuer_n_hash, year, month)
      issuer = sp_issuer_n_hash[0]
      sp_hash = sp_issuer_n_hash[1]
      ial = sp_hash['ial']
      agency = sp_hash['agency']
      total = number_with_delimiter(count(issuer, "#{year}#{padded_month(month)}"))
      dest_fn = billing_fn(dir, agency, issuer)
      generate_pdf(fn: dest_fn, agency: agency, issuer: issuer, month: month, year: year,
                   friendly_name: sp_hash['friendly_name'], ial: ial, total: total)
    end

    def billing_fn(dir, agency, issuer)
      "#{dir}/billing-report.#{agency.downcase}.#{issuer.downcase.gsub(/[^0-9a-z ]/i, '-')}.pdf"
    end

    # rubocop:disable Metrics/MethodLength
    def generate_pdf(fn:, agency:, issuer:, month:, year:, friendly_name:, ial:, total:)
      data = chart_data(issuer, year, month, ial)
      Prawn::Document.generate(fn) do
        image LOGO_FN, width: 500
        text "\nBilling Report for #{Date::MONTHNAMES[month]} #{year}\n\n", size: 28, align: :center
        text Time.zone.today.strftime('%B %-d, %Y')
        text "\n"
        text "Agency: #{agency}"
        text "Application: #{friendly_name}\n\n"
        text "Total IAL#{ial} Authentications for the month: #{total}\n\n"
        chart data
      end
    end
    # rubocop:enable Metrics/MethodLength

    def chart_data(issuer, target_year, target_month, ial)
      prior_hash = {}
      current_hash = {}
      chart_data_prior_months(prior_hash, current_hash, issuer, target_year, target_month)
      chart_data_current_month(prior_hash, current_hash, issuer, target_year, target_month)
      { "IAL#{ial} Authentications Previous Months": prior_hash,
        "IAL#{ial} Authentications Current Month": current_hash }
    end

    def chart_data_prior_months(prior_hash, current_hash, issuer, target_year, target_month)
      TOTAL_PRIOR_MONTHS.downto(1) do |offset|
        year, month = previous_month(target_year, target_month, offset)
        month_str = Date::MONTHNAMES[month][0..2]
        prior_hash["#{month_str} #{year}"] = count(issuer, "#{year}#{padded_month(month)}")
        current_hash["#{month_str} #{year}"] = 0
      end
    end

    def chart_data_current_month(prior_hash, current_hash, issuer, target_year, target_month)
      month_str = Date::MONTHNAMES[target_month][0..2]
      current_hash["#{month_str} #{target_year}"] = \
        count(issuer, "#{target_year}#{padded_month(target_month)}")
      prior_hash["#{month_str} #{target_year}"] = 0
    end

    def padded_month(month)
      format('%02d', month)
    end

    def previous_month(year, month, offset)
      month -= offset
      if month <= 0
        month += 12
        year -= 1
      end
      [year, month]
    end

    def number_with_delimiter(number)
      number.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse
    end

    def count(issuer, year_month)
      @issuer_year_month_to_count["#{issuer}|#{year_month}"].to_i
    end

    def service_providers(sp_yml)
      content = ERB.new(File.read(sp_yml)).result
      YAML.safe_load(content).fetch('production')
    end

    def parse_total_monthly_auths_json(auths_json_fn)
      results = {}
      arr = JSON.parse(File.read(auths_json_fn))
      arr.each do |hash|
        issuer = hash['issuer']
        year_month = hash['year_month']
        results["#{issuer}|#{year_month}"] = hash['total']
      end
      results
    end
  end
end
