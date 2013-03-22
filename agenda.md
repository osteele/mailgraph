# Next
* Run on Heroku
* Update mail on login
* Allow user to mark email addresses as equivalent
* Default to the most common name as the person's name
* Tag cloud for senders
* Mute senders
* Link from home page
* Filter to direct messages
* Switch between senders and recipients
* Select time window
* Remove account owner
* Trigger jobs when user signs in
* Sweep the cache on update

# Later
* Use contacts to consolidate addresses
* Landing page that doesn't force login
* More graph types
* Show “other”
* Sass
* Asset compression
* Serve API via Grape https://github.com/intridea/grape
* Marker for which months have been completed?
* message.envelope.in_reply_to
* Adaptive time periods
* Update mail messages in background
* Remove deleted messages
* Scan multiple folders (and filter by gid)

# Future
* Index messages
* Sentiment analysis

# Notes

## Run on Heroku

Alternatives:
1. Install npm on heroku.
2. Rewrite the front end in nodejs.
3. Move the front end to meteor.
4. Commit the bower files.
5. Switch back from bower.

## API Publication
* http://www.3scale.net/2012/06/the-10-minute-api-up-running-3scale-grape-heroku-api-10-minutes/
* https://github.com/3scale/3scale_ws_api_for_ruby
* https://support.3scale.net/quickstarts/hello-world-api

## Asset compression

    require "yui/compressor"
    settings.assets.js_compressor  = YUI::JavaScriptCompressor.new
    settings.assets.css_compressor = YUI::CssCompressor.new

    expires Time.now + (365*24*60*60) if settings.production?

https://github.com/kalasjocke/sinatra-asset-pipeline/blob/master/Rakefile
