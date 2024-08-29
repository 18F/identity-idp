# frozen_string_literal: true

unless ARGV.size == 1
  puts "usage: #{$PROGRAM_NAME} <yaml-file>"
  exit false
end

$funny_characters = {}

File.open(ARGV[0], 'r:utf-8') do |yaml_file|
  yaml_file.each do |line|
    line.codepoints do |codepoint|
      if codepoint. > 127
        character_data = $funny_characters[codepoint] =
          $funny_characters[codepoint] || { line: [] }
        character_data[:line] << yaml_file.lineno
      end
    end
  end
end

$funny_characters.sort_by do |character, entry|
  [-entry[:line].length, character]
end.each do |key, value|
  key_as_string = +'' << key
  puts "character #{key_as_string.inspect} (#{key.to_s}) (0x#{key.to_s(16)}) occurs #{value[:line].size} times"
  puts "  #{value[:line].sort.map(&:inspect).join(' ')}"
  puts
end
