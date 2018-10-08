#!/usr/bin/ruby

# http://beets.readthedocs.io/en/v1.4.6/plugins/play.html
# http://beets.readthedocs.io/en/v1.4.6/plugins/lyrics.html
# http://beets.readthedocs.io/en/v1.4.6/plugins/chroma.html
# http://docs.puddletag.net/download.html

# possibly best https://github.com/spotify/echoprint-codegen

require 'optparse'
require 'io/console'
require 'thread'

Thread.report_on_exception = false

@@size_x = 80
@@size_y = 39 # define terminal size (rows, columns)

@@music_dir = 'Whatever you want'
@@exclusions = ['$RECYCLE.BIN', 'System Volume Information']
              .map { |e| " -not \\( -path '#{@@music_dir + '/' + e}' -prune \\)" }.join # format for find cmd
@@music_file_extension = "-type f \\( -iname '*.mp3' -o -iname '*.flac' \\)"

@@text_help = "\"\n\r\t(h) This help\n\r\t( ) Pause\n\r\t(p) Previous song\n\r\t(r) Restart song\n\r\t(n) Next song\n\r\t[0-9] Jump x songs\n\r\t(-) Toggle jump direction\n\r\t(q) Exit program\n\r\""
@@text_blank = "\"#{(' ' * @@size_x + "\n\r") * @@text_help.count("\n")}\""

class MusicPlayer
  def initialize
    @run = true
    @cmd = %w[STOP CONT]
    @toggle_pause = 0
    @toggle_help = 1
    @queue_length = 0
    get_options

    Dir.chdir @@music_dir
    terminal_size(@@size_x, @@size_y)
    clear_terminal
    hide_cursor

    search_songs
    format_songs
    user_input

    if @options[:list]
      print_songs
    else
      play_songs
    end
  end

  def get_options
    @options = { name: '', type: 'd', rand: false, saga: false, list: false }
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

        opts.on('-l', '--list', 'Only lists corresponding files') do
          @options[:list] = true
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
    cmd = "find '#{@@music_dir}' #{@@exclusions}"

    if @options[:type] == 'd' # we are in folder mode
      # find the first folder whose name match @options[:name]
      cmd += " -type d -iname '*#{@options[:name].tr(' ', '*')}*' -print -quit"
      dir = '"' + `#{cmd}`.chomp + '"'

      if dir.empty?
        puts '[MUSIC][SEARCH] Nothing found, try searching for something else'
        abort
      end

      if @options[:list] # we are in list mode
        cmd = "find #{dir} -maxdepth 1 #{@@exclusions} -type d" # list all the subfolders in the found folder
      else
        cmd = "find #{dir} #{@@exclusions} #{@@music_file_extension}" # play all the songs in the found folder
      end
    else # we are in file mode
      # find all the songs whose name match @options[:name]
      cmd += " #{@@music_file_extension} -a -iname '*#{@options[:name].tr(' ', '*')}*'"
    end

    @songs = `#{cmd}`.split('\n') # if list, display directories
    if @songs.empty?
      puts '[MUSIC][SEARCH] Nothing found, try searching for something else'
      abort
    end

    @queue_length = @songs.length
    puts "[MUSIC][SEARCH] Found'em ! Queuing..."
    puts "[MUSIC][PLAY] Playing the following #{@queue_length} songs in #{@options[:rand] ? 'shuffle' : 'sequential'} mode" unless @options[:list]
  end

  def format_songs
    @songs.shuffle! if @options[:rand]
    @song_names = @songs.map { |path| "\t#{sanitize_filename(path)}"[0..@@size_x - 10].ljust(@@size_x - 2) + "\r" } # adjust song names for terminal size
  end

  def sanitize_filename(path)
    path.match /^.*[\\|\/](.*)$/
    name = $2
    name.gsub!(/\W/, '_')
  end

  def print_songs
    while @run
      string = "\"[MUSIC][LIST] Press h to see the keyboard shortcuts\n\r\n\r\n\r"

      # print only the surrounding 25 songs at most
      prev = @song_names[-12..-1]
      string += prev.join unless prev.nil?
      string += "[HERE]#{@song_names[0]}"
      string += @song_names[1..12].join + '"'
      cursor_to_top
      printf string

      @current_song = Thread.new do
        system('sleep 1000')
      end

      @current_song.join
      rotate_songs 1
    end
  end

  def play_songs
    offset = @@size_x - 5
    while @run
      string = "\"[MUSIC][PLAY] Press h to see the keyboard shortcuts\n\r"
      song_length = `soxi -d "#{@songs[0]}"`[3..-5].chomp
      string += "Playing #{@song_names[0].strip[0..@@size_x - 37]} (#{song_length}) of #{@queue_length} songs".ljust(offset) + "\n\r\n\r\n\r"

      # print only the surrounding 25 songs at most
      prev = @song_names[-12..-1]
      string += prev.join unless prev.nil?
      string += "[PLAY]#{@song_names[0]}"
      string += @song_names[1..12].join + '"'
      cursor_to_top
      printf string

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
          pause_song unless @options[:list]
        when '-'
          neg *= -1
        when "\e[B", "\e[C", 'n', '1'
          next_song
        when "\e[A", "\e[D", 'p'
          prev_song
        when 'r', '0', "\r"
          if @options[:list] # choose directory and restart script with new selection
            @run = false
            kill_song
            new_name = sanitize_filename(@song_names[0].strip)
            system("music -n#{new_name}#{@options[:rand] ? ' -r' : ''}")
            abort
          else
            jump_song 0
          end
        when 'h'
          toggle_help
        when 'q'
          @run = false
          pause_song if @toggle_pause == 1
          kill_song
          clear_terminal
          show_cursor
          Thread.exit
        when /[2-9]/
          jump_song (input.to_i * neg)
        end
      end
    end
  end

  # ACTIONS
  def rotate_songs n
    @songs.rotate! n
    @song_names.rotate! n
  end

  def kill_song
    if @options[:list]
      system("kill #{`pidof sleep`.chomp} > /dev/null")
    else
      system("kill #{`pidof play`.chomp} > /dev/null")
    end
    @current_song.kill
  end

  def next_song
    kill_song
  end

  def prev_song
    rotate_songs -2
    next_song
  end

  def jump_song x
    rotate_songs (x - 1)
    next_song
  end

  def pause_song
    system("kill -#{@cmd[@toggle_pause]} #{`pidof play`.chomp} > /dev/null")
    @toggle_pause ^= 1
  end

  def toggle_help
    save_cursor_pos
    if @toggle_help == 1
      printf @@text_help
    else
      printf @@text_blank
    end
    restore_cursor_pos
    @toggle_help ^= 1
  end

  def clear_terminal
    print "\e[2J\e[f"
  end

  def show_cursor
    print "\e[?25h"
  end

  def hide_cursor
   print "\e[?25l"
  end

  def cursor_to_top
    print "\033[;H" # place cursor at top
  end

  def save_cursor_pos
    print "\033[s"
  end

  def restore_cursor_pos
    print "\033[u"
  end

  def terminal_size(x,y)
    system("printf '\e[8;#{x};#{y}t'") # set terminal size
  end
end

MusicPlayer.new
