#!/usr/bin/ruby

# TODO http://beets.readthedocs.io/en/v1.4.6/plugins/play.html
# http://beets.readthedocs.io/en/v1.4.6/plugins/lyrics.html
# http://beets.readthedocs.io/en/v1.4.6/plugins/chroma.html
# http://docs.puddletag.net/download.html

# possibly best https://github.com/spotify/echoprint-codegen

require 'optparse'
require 'io/console'
require 'thread'

class MusicPlayer

  def initialize
	  @music_dir = 'Whatever you want'
	  @exclusions = ['$RECYCLE.BIN', 'System Volume Information']
		                .map{|e| " -not \\\( -path '#{@music_dir  + '/' + e}' -prune \\\)"}.join # format for find cmd
	  @size_x = 90
	  @size_y = 39

	  @help = "\"\n\r\t(h) This help\n\r\t( ) Pause\n\r\t(p) Previous song\n\r\t(r) Restart song\n\r\t(n) Next song\n\r\t[0-9] Jump x songs\n\r\t(-) Toggle jump direction\n\r\t(q) Exit program\n\r\""
	  @length = @help.count("\n")
	  @blank = "\"#{(' ' * @size_x + "\n\r") * @length}\""

	  @cmd = %w[STOP CONT]
	  @toggle_pause = 0
	  @toggle_help = 1
    get_options

    Dir.chdir @music_dir
    system("printf '\e[8;#{@size_y};#{@size_x}t'") # set terminal size (40 rows, 80 columns)
    system('clear')
    system("printf '\e[?25l'") # hide cursor

    search_songs
    format_songs
    user_input
    play_songs
  end

  def get_options
    @options = { name: '', type: 'd', rand: false, saga: false }
    OptionParser.new do |opts|
      begin
        opts.banner = 'Usage: music [@options]'

        opts.on('-nNAME', '--name NAME', 'Search for keywords') do |name|
          @options[:name] = name
        end

        opts.on('-f', '--file', 'Search for files (default folders)') do
          @options[:type] = 'f'
        end

        opts.on('-r', '--rand', 'Shuffle the playlist') do
          @options[:rand] = true
        end

        opts.on('-h', '--help', 'Prints this help') do
          puts opts
          exit
        end
      rescue OptionParser::InvalidOption
        puts opts
        exit
      end
    end.parse!
  end

  def search_songs
  	if @options[:type] == 'd'
        cmd = "find '#{@music_dir}'"
        cmd += @exclusions
        cmd += " -type d -iname '*#{@options[:name].tr(' ', '*')}*' -print -quit"
        dir = `#{cmd}`.chomp

        if dir.empty?
          puts '[MUSIC][SEARCH] Nothing found, try searching for something else'
          return
        end

        cmd = "find '#{dir}'"
        cmd += @exclusions
        cmd += " -type f -iname '*.mp3' -o -iname '*.flac'"
  	else
  	    cmd = "find '#{@music_dir}'"
        cmd += @exclusions
        cmd += " -type f \\\( -iname '*.mp3' -o -iname '*.flac' \\\) -a -iname '*#{@options[:name].tr(' ', '*')}*'"
  	end

    @songs = `#{cmd}`.split(/\n/)
    if @songs.empty?
      puts '[MUSIC][SEARCH] Nothing found, try searching for something else'
      return
    end

    @length = @songs.length
    puts "[MUSIC][SEARCH] Found'em ! Queuing..."
    puts "[MUSIC][PLAY] Playing the following #{@length} songs in #{@options[:rand] ? 'shuffle' : 'sequential'} mode"
  end

  def format_songs
    @songs.shuffle! if @options[:rand]
    @song_names = @songs.map { |song| "\t#{song[song.rindex('/')+1..-1]}"[0..@size_x-2].ljust(@size_x - 2) + "\r" } # adjust song names for terminal size
  end

  def play_songs
  	offset = @size_x - 5
    while @run
      string = "\"[MUSIC][PLAY] Press h to see the keyboard shortcuts\n\r"
      song_length = `soxi -d "#{@songs[0]}"`[3..-5].chomp
      string += "Playing #{@song_names[0].chomp.chomp.strip[0..@size_x-37]} (#{song_length}) of #{@length} songs".ljust(offset) + "\n\r\n\r\n\r"

      # print only the surrounding 25 songs at most
      prev = @song_names[-12..-1]
      string += prev.join unless prev.nil?
      string += "[PLAY]#{@song_names[0]}"
      string += @song_names[1..12].join + '"'
      system("printf '\033[;H'") # place cursor at top
      system("printf #{string}") # print

      @current_song = Thread.new do
        str = '"' + @songs[0] + '"' # sanitize string
        system("play -V1 -q #{str}")
      end

      @current_song.join
      rotate_songs 1
    end
  end

  def user_input
    @run = true
    neg = 1
    @user_input = Thread.new do
      loop do
        input = STDIN.getch
        if input == "\e"
          input << STDIN.read_nonblock(3) rescue nil
          input << STDIN.read_nonblock(2) rescue nil
        end

        case input
        when ' '
          pause_song
        when '-'
          neg *= -1
        when "\e[B", "\e[C", 'n', '1'
          next_song
        when "\e[A", "\e[D", 'p'
          prev_song
        when 'r'
          jumpSong 0
        when 'h'
          toggle_help
        when 'q'
          @run = false
          pause_song if @toggle == 1
          system("kill #{`pidof play`}")
          system('clear')
          system("printf '\u001B[?25h'") # show cursor
          Thread.exit
        when '2', '3', '4', '5', '6', '7', '8', '9'
          jumpSong (input.to_i * neg)
        end
      end
    end
  end

  # ACTIONS
  def rotate_songs n
    @songs.rotate! n
    @song_names.rotate! n
  end

  def next_song
  	@current_song.kill
  	system("kill #{`pidof play`.chomp} > /dev/null")
  end

  def prev_song
    rotate_songs -2
    @current_song.kill
    system("kill #{`pidof play`.chomp} > /dev/null")
  end

  def jumpSong x
    rotate_songs (x - 1)
    next_song
  end

  def pause_song
    system("kill -#{@cmd[@toggle_pause]} #{`pidof play`.chomp} &> /dev/null")
    @toggle_pause = 1 - @toggle_pause
  end

  def toggle_help
    system("printf '\033[s'")
    if @toggle_help == 1
      system("printf #{@help}")
    else
      system("printf #{@blank}")
    end
    system("printf '\033[u'")
    @toggle_help = 1 - @toggle_help
  end
end

MusicPlayer.new
