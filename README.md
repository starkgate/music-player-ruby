# music-player-ruby
Command line only music player

**Introduction**

CLI-only Ruby script to quickly create and run a playlist. I couldn't find something that corresponded to what I wanted (tried mpg123 and a few others), so I made my own. Uses sox to run the music.

**Requirements**

Ruby 2.4+ on either Linux or Windows.

**Usage**

First open the script file and edit the music_dir variable to point to your own music's path.

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
- Keyboard shortcuts to go to previous, next songs.
- Lightweight.

![](http://imgur.com/RmieDJS.png)
