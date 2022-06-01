namespace :convert_application_yml_to_proper_types do
  desc 'Take application.yml input file and convert to proper type'
  task :convert, [:filename] => :environment do |t, args|
    filename = args[:filename]
    if filename
      content = ''
      add_spaces = false
      File.open(filename + '.tmp', 'w') do |newfile|
        IO.foreach(filename) do |line|
          add_spaces = true if line.include?('development:')
          content = line
          key, value = line.split(':', 2).map(&:strip)

          if key && value && (!['development', 'test', 'production'].include? key)
            value_type = value_types[key]
            converted_val = convert(value, value_type)
            content = "#{key}: #{converted_val}"
            content = "  #{key}: #{converted_val}" if add_spaces
          end

          newfile.puts content.rstrip
        end
      end
      FileUtils.mv filename + '.tmp', filename
    else
      puts 'Please specify argument of filename.'
      puts 'Example: rake convert_application_yml_to_proper_types:convert[application.yml]'
    end
  end

  def value_types
    @value_types ||= begin
      types = {}
      IO.foreach("#{Rails.root}/lib/identity_config.rb") do |line|
        if (line.strip.index('config.add') == 0)
          line = line.split(':')
          name = nil
          type = nil
          if line.length == 2
            name = line[1].strip[0..-2]
            type = 'string'
          elsif line.length == 4
            name = line[1].split(',').first
            type = line.last.strip[0..-2]
          elsif line.length == 5
            name = line[1].split(',').first
            type = line[3].split(',').first
          elsif line.length == 6
            name = line[1].split(',').first
            type = line[3].split(',').first
          end
          types[name] = type
        end
      end
      types
    end
  end

  def convert(value, value_type)
    case value_type
    when 'float'
      value.tr("'", '').to_f
    when 'boolean'
      JSON.parse(YAML.safe_load(value).to_s) == true
    when 'integer'
      value.tr("'", '').to_i.to_s(:delimited, delimiter: '_')
    else
      value
    end
  end
end
