# Ruby Music Player
Command line only music player

**Introduction**

CLI-only Ruby script to quickly create and run a playlist. I couldn't find something that corresponded to what I wanted (tried mpg123 and a few others), so I made my own. Uses sox to play the music.

**Requirements**

- Ruby 2.4+ on either Linux or Windows.
- sox and libraries to read the audio files : `sudo apt install sox libsox-fmt-mp3`

**Usage**

First open the script file and edit the music_dir variable to point to your own music's path. Then run the script itself with `ruby music.rb`. Or put it in your `/usr/bin` folder and just type `music`. By default this will start playing your entire library in a playlist :). If you want more options (why ?), see below !

```
Usage: music [options]
    -n, --name NAME                  Search for keywords
    -f, --file                       Search for files (default folders)
    -r, --rand                       Shuffle the playlist
    -h, --help                       Prints this help
```

Example: `music -nChopin -r`

Will find the first folder with the word "Chopin" in it (not case sensitive), and will start playing all the music files within (MP3, FLAC) in a random order.

**Features**

- Dynamically displays the current state of the playlist.
- Keyboard shortcuts to pause, go to previous, next songs.
- Lightweight.

![](http://imgur.com/RmieDJS.png)
