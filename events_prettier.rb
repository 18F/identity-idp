File.open(ARGV[0]) do |f|
  while !f.eof
    line = f.readline
    if line =~ /"Path visited".*"method":"([^"]+)".*"path":"([^"]+)"/
      puts "\n#{$1} #{$2}\n"
    else
      puts line
    end
  end
end
