# Next
* Display tag of people
* Streamgraph from contacts
* Update messages; sweep the cache
* Select year
* Switch between senders and recipients
* Incremental update
  test whether UIDNEXT has incremented?
* Mobile view

## Bugs
* why does frequent correspondents query scan contacts twice?
* Update mail is no longer skipping seen uid's

## Public
* ANALYZE
* Scan contacts
* Handle duplicate addresses
* Prompt to enable All
* Scan more mailboxes if All is not present
* Either email addresses are per account, or canonical address is a separate table (or always use Person)
* Update mail on login
* Update mail messages in background
* Landing page doesn't force login
* Separate login from authentication
* Explain why permissions are requested
* Warn if folders list doesn't include All
* ToS, Privacy, Contact
* Wait List

## Data Quality
* Default to the most common name as the person's name
* Remove deleted messages
* Scan multiple folders (and filter by gid)

## Architecture
* Rewrite client in angular / derby
  http://briantford.com/blog/angular-phonegap.html
* Sass
* Asset compression
* message.envelope.in_reply_to
* Adaptive time periods

# Notes

## Delete Messages
* A: During full update, record uid's in db that aren't in fetch. Cons: requires full update.
* B: Iterate through the database in blocks, doing fetch for each block.
* C: Track which timespans we've asked for recently; add messages.refreshed_at; delete messages in that timespan.

## API Server
* Grape https://github.com/intridea/grape
* Publication
  * http://www.3scale.net/2012/06/the-10-minute-api-up-running-3scale-grape-heroku-api-10-minutes/
  * https://github.com/3scale/3scale_ws_api_for_ruby
  * https://support.3scale.net/quickstarts/hello-world-api

## Asset compression

    require "yui/compressor"
    settings.assets.js_compressor  = YUI::JavaScriptCompressor.new
    settings.assets.css_compressor = YUI::CssCompressor.new

    expires Time.now + (365*24*60*60) if settings.production?

https://github.com/kalasjocke/sinatra-asset-pipeline/blob/master/Rakefile
