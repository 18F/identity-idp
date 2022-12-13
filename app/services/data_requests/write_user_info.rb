require 'csv'

module DataRequests
  class WriteUserInfo
    attr_reader :user_report, :output_dir

    def initialize(user_report, output_dir)
      @user_report = user_report
      @output_dir = output_dir
    end

    def call
      write_emails
      write_phone_configurations
      write_auth_app_configurations
      write_webauthn_configurations
      write_piv_cac_configurations
      write_backup_code_configurations
      output_file.close
    end

    private

    def output_file
      @output_file ||= begin
        output_path = File.join(output_dir, 'user.csv')
        File.open(output_path, 'w')
      end
    end

    def write_rows_to_csv(rows, *columns)
      output_file.puts(columns.join(','))

      return output_file.puts("No data\n\n") if rows.empty?

      rows.each do |row|
        output_file.puts CSV.generate_line(row.values_at(*columns))
      end
      output_file.puts("\n")
    end

    def write_auth_app_configurations
      output_file.puts('Auth app configurations:')
      write_rows_to_csv(
        user_report[:mfa_configurations][:auth_app_configurations],
        :name,
        :created_at,
      )
    end

    def write_backup_code_configurations
      output_file.puts('Backup code configurations:')
      write_rows_to_csv(
        user_report[:mfa_configurations][:backup_code_configurations],
        :created_at,
        :used_at,
      )
    end

    def write_emails
      output_file.puts('Emails:')
      write_rows_to_csv(user_report[:email_addresses], :email, :created_at, :confirmed_at)
    end

    def write_phone_configurations
      output_file.puts('Phone configurations:')
      write_rows_to_csv(
        user_report[:mfa_configurations][:phone_configurations],
        :phone,
        :created_at,
        :confirmed_at,
      )
    end

    def write_piv_cac_configurations
      output_file.puts('PIV/CAC configurations:')
      write_rows_to_csv(
        user_report[:mfa_configurations][:piv_cac_configurations],
        :name,
        :created_at,
      )
    end

    def write_webauthn_configurations
      output_file.puts('WebAuthn configurations:')
      write_rows_to_csv(
        user_report[:mfa_configurations][:webauthn_configurations],
        :name,
        :created_at,
      )
    end
  end
end
