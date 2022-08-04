class DateTimeInput < SimpleForm::Inputs::DateTimeInput
    def month_label(wrapper_options = nil)
      @month_label ||= begin
        options[:month_label].to_s.html_safe if options[:month_label].present?
      end
    end

    def day_label(wrapper_options = nil)
      @day_label ||= begin
        options[:day_label].to_s.html_safe if options[:day_label].present?
      end
    end

    def year_label(wrapper_options = nil)
      @year_label ||= begin
        options[:year_label].to_s.html_safe if options[:year_label].present?
      end
    end
end
