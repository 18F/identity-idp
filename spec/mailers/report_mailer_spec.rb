require 'rails_helper'
require 'simple_xlsx_reader'

RSpec.describe ReportMailer, type: :mailer do
  let(:user) { build(:user) }
  let(:email_address) { user.email_addresses.first }

  describe '#deleted_user_accounts_report' do
    let(:mail) do
      ReportMailer.deleted_user_accounts_report(
        email: email_address.email,
        name: 'my name',
        issuers: %w[issuer1 issuer2],
        data: 'data',
      )
    end

    it_behaves_like 'a system email'

    it 'sends to the current email' do
      expect(mail.to).to eq [email_address.email]
    end

    it 'renders the subject' do
      expect(mail.subject).to eq t('report_mailer.deleted_accounts_report.subject')
    end

    it 'renders the body' do
      expect(mail.html_part.body).to have_content('my name')
      expect(mail.html_part.body).to have_content('issuer1')
      expect(mail.html_part.body).to have_content('issuer2')
    end
  end

  describe '#warn_error' do
    let(:error) { RuntimeError.new('this is my test message') }
    let(:env) { ActiveSupport::StringInquirer.new('prod') }

    let(:mail) do
      ReportMailer.warn_error(
        email: 'test@example.com',
        error:,
        env:,
      )
    end

    it 'puts the rails env and error in a plaintext email', aggregate_failures: true do
      expect(mail.html_part).to be_nil

      expect(mail.subject).to include('prod')
      expect(mail.subject).to include('RuntimeError')

      expect(mail.text_part.body).to include('this is my test')
    end
  end

  describe '#tables_report' do
    let(:env) { 'prod' }
    let(:attachment_format) { :csv }

    let(:first_table) do
      [
        ['Some', 'String'],
        ['a', 'b'],
        ['c', 'd'],
      ]
    end

    let(:second_table) do
      [
        ['Float', 'Int', 'Float'],
        ['Row 1', 1, 0.5],
        ['Row 2', 1, 1.5],
      ]
    end

    let(:third_table) do
      [
        ['Float As Percent', 'Gigantic Int', 'Float'],
        ['Row 1', 100_000_000, 1.0],
        ['Row 2', 123_456_789, 1.5],
      ]
    end

    let(:mail) do
      ReportMailer.tables_report(
        email: 'foo@example.com',
        subject: 'My Report',
        message: 'My Report - Today',
        env:,
        attachment_format:,
        reports: [
          Reporting::EmailableReport.new(table: first_table),
          Reporting::EmailableReport.new(
            table: second_table,
            float_as_percent: true,
            title: 'Custom Table 2',
          ),
          Reporting::EmailableReport.new(
            table: third_table,
            float_as_percent: false,
            title: 'Custom Table 3 With Very Long Name',
          ),
        ],
      )
    end

    it 'does not attach the Login.gov logo' do
      expect(mail.attachments.map(&:filename)).to_not include('logo.png')
    end

    it 'renders the tables in HTML', aggregate_failures: true do
      doc = Nokogiri::HTML(mail.html_part.body.to_s)

      expect(doc.css('h2').map(&:text)).
        to eq(['Table 1', 'Custom Table 2', 'Custom Table 3 With Very Long Name'])

      _first_table, percent_table, float_table = doc.css('table')

      percent_cell = percent_table.at_css('tbody tr:nth-child(1) td:last-child')
      expect(percent_cell.text.strip).to eq('50.00%')
      expect(percent_cell['class']).to eq('table-number')

      float_cell = float_table.at_css('tbody tr:nth-child(1) td:last-child')
      expect(float_cell.text.strip).to eq('1.0')
      expect(percent_cell['class']).to eq('table-number')

      big_int_cell = float_table.at_css('tbody tr:nth-child(1) td:nth-child(2)')
      expect(big_int_cell.text.strip).to eq('100,000,000')
    end

    context 'with attachment_format: :csv' do
      let(:attachment_format) { :csv }

      it 'renders each table as a separate CSV', aggregate_failures: true do
        expect(mail.attachments.map(&:filename)).to eq(
          [
            'table-1.csv',
            'custom-table-2.csv',
            'custom-table-3-with-very-long-name.csv',
          ],
        )

        tables = mail.attachments.map { |a| CSV.parse(a.read) }

        expect(tables).to eq(
          [first_table, second_table, third_table].
            map { |table| table.map { |row| row.map(&:to_s) } },
        )
      end
    end

    context 'with attachment_format: :xlsx' do
      let(:attachment_format) { :xlsx }

      it 'combines all the tables into one .xlsx', aggregate_failures: true do
        expect(mail.attachments.size).to eq(1)

        attachment = mail.attachments.first
        expect(attachment.filename).to eq('report.xlsx')

        xlsx = SimpleXlsxReader.parse(attachment.read)
        expect(xlsx.sheets.map(&:name)).to(
          eq(['Table 1', 'Custom Table 2', 'Custom Table 3 With Very Long N']),
          'truncates sheet names to fit within 31-byte XLSX limit',
        )

        expect(xlsx.sheets.first.rows.to_a).to eq(first_table)
      end
    end

    context 'another attachment format' do
      let(:attachment_format) { :pdf }

      it 'throws' do
        expect { mail.read }.to raise_error(ArgumentError, 'unknown attachment_format=pdf')
      end
    end
  end
end
