module DataRequests
  class WriteUserEvents
    attr_reader :user_report, :output_dir

    def initialize(user_report, output_dir)
      @user_report = user_report
      @output_dir = output_dir
    end

    def call
      File.open(File.join(output_dir, 'events.csv'), 'w') do |file|
        file.puts('event_name,date_time,ip,disavowed_at,user_agent,device_cookie')
        user_report[:user_events].each do |row|
          file.puts(
            CSV.generate_line(
              row.values_at(
                :event_name,
                :date_time,
                :ip,
                :disavowed_at,
                :user_agent,
                :device_cookie,
              ),
            ),
          )
        end
      end
    end
  end
end
