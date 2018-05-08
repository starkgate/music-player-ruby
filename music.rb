#!/usr/bin/ruby

require 'optparse'
require 'io/console'
require 'thread'

music_dir = "PUT WHATEVER YOU LIKE HERE"
# in case you only want specific folders to be scanned in your music directory
music_folders = ""

options = {:name => "", :type => 'd', :rand => false}
OptionParser.new do |opts|
  opts.banner = "Usage: music [options]"

  opts.on("-nNAME", "--name NAME", "Search for keywords") do |name|
    options[:name] = name
  end

  opts.on("-f", "--file", "Search for files (default folders)") do |name|
    options[:type] = 'f'
  end

  opts.on("-r", "--rand", "Shuffle the playlist") do |name|
    options[:rand] = true
  end

  opts.on("-h", "--help", "Prints this help") do
    puts opts
    exit
  end
end.parse!

Dir.chdir music_dir
search = `find #{music_folders} -type #{options[:type]} -iname '*#{options[:name].gsub(/\s/, "*")}*'`
if search == ""
  puts "[MUSIC][SEARCH] Nothing found, try searching for something else"
  return
else
  puts "[MUSIC][SEARCH] Found'em ! Queuing..."
end

@songs = search.split(/\n/)
if options[:type] == "d"
  if options[:name] == ""
    play = music_folders # entire library
  else
    play = @songs[0]
  end
  @songs = `find '#{play}' -type f -iname '*.mp3' -o -iname '*.flac'`.split(/\n/)
end
puts "[MUSIC][PLAY] Playing the following #{@songs.length} songs in #{options[:rand] ? 'shuffle' : 'sequential'} mode"

@songs.shuffle! if options[:rand]
@song_names = @songs.map{|song| "\t" + song.gsub(/^.*\//, "") + "\n\r"}

def rotateSongs n
  @songs.rotate! n
  @song_names.rotate! n
end

def nextSong
  system("kill #{`pidof play`}")
end

def prevSong
  rotateSongs -2
  system("kill #{`pidof play`}")
end

def jumpSong x
  rotateSongs (x-1)
  nextSong
end

run = true
neg = 1
cmd = ["STOP", "CONT"]
toggle = 0
@user_input = Thread.new do
  while(true)
    input = STDIN.getch
    if input == "\e" then
      input << STDIN.read_nonblock(3) rescue nil
      input << STDIN.read_nonblock(2) rescue nil
    end

    case input
    when " "
    	system("kill -#{cmd[toggle]} #{`pidof play`}")
    	toggle = 1 - toggle
    when "-"
      neg *= -1
    when "\e[B", "\e[C", 'n', "1"
      nextSong
    when "\e[A", "\e[D", 'p'
      prevSong
    when 'h'
      printf "\n\t(h) This help\n\t(q) Exit program\n\t( ) Pause\n\t(p) Previous song\n\t(n) Next song\n\t[0-9] Jump x songs\n\t(-) Toggle jump direction\n\r"
    when 'q'
      run = false
      system("kill #{`pidof play`}")
      Thread.exit
    when "2","3","4","5","6","7","8","9"
      jumpSong (input.to_i*neg)
    end
    STDIN.echo = false
    sleep 0.2
    STDIN.echo = true
  end
end

while(run)
  system("clear")
  printf "[MUSIC][PLAY] Press h to see the keyboard shortcuts\n\r"
  song_length = `soxi -d '#{@songs[0]}'`.slice(3..-5).chomp
  printf "Playing #{@song_names[0].lstrip.chomp.chomp} (#{song_length}) of #{length} songs\n\r\n\r\n\r"

  # print only the surrounding 25 songs at most
  printf @song_names[-12..-1].join
  print "[PLAY]#{@song_names[0]}"
  printf @song_names[1..12].join # remove leading path, keep only filenames of songs

  @current_song = Thread.new do
  	STDIN.echo = false
    system("play -V1 -q '#{@songs[0]}'")
  end
  @current_song.join
  rotateSongs 1
end
