#! /bin/bash

if [ "$#" -ne 2 ]; then
  echo "Usage: dla [browser] [url]"
  echo "       dla chrome \'https://music.youtube.com/playlist?list=OLAK5uy_nvaP-wWf8dpuVXdsddndZoObe5jWYz9MI\'"
  exit 1
fi
BROWSER=$1
URL=$2

yt-dlp -f bestaudio --ppa "ThumbnailsConvertor+FFmpeg_o:-c:v mjpeg -vf crop=\"'if(gt(ih,iw),iw,ih)':'if(gt(iw,ih),ih,iw)'\"" --extract-audio --embed-thumbnail --embed-metadata --parse-metadata 'playlist_index:%(meta_track)s' --convert-thumbnails jpg -o "%(playlist_index)s %(title)s.%(ext)s" --cookies-from-browser "$BROWSER" "$URL"
