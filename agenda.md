# Next
* Add Sent messages
* Consolidate addresses
* Update messages
* Allow user to mark email addresses as equivalent
* Filter to direct messages
* Switch between senders and recipients
* Sweep the cache on update

# Future
## Public
* Update mail on login
* Update mail messages in background
* Link from home page
* Landing page that doesn't force login
* Warn if folders list doesn't include All
* ToS, Privacy
* Wait List

## Data Quality
* Default to the most common name as the person's name
* Remove deleted messages
* Scan multiple folders (and filter by gid)

## Features
* Mute senders
* Index messages
* Sentiment analysis
* Contacts https://developers.google.com/google-apps/contacts/v3/#retrieving_contacts_using_query_parameters

## Presentation
* Tag cloud
  * Add size
  * Sort by frequency, name, last contact
  * Filter by sender, recipient, timespan
* Stream graph
  * Filter by sender, recipient, timespan
* More analogs http://betabeers.com/uploads/estudios/crunchbase-startup-data/?
  * Bar char: Incoming vs. Outgoing by year
  * Pie char: Top Senders 2012 [choose year]; Top Recipients 2012
  * Tables: Top correspondents by year [range of years]

## Architecture
* Separate into API server and angular / derby
  http://briantford.com/blog/angular-phonegap.html
* Sass
* Asset compression
* Serve API via Grape https://github.com/intridea/grape
* Marker for which months have been completed?
* message.envelope.in_reply_to
* Adaptive time periods

# Notes

## Consolidate Addresses
### Contacts
* Build a join table: email address <-> contact
* For each email address that is joined to only one contact, join it to the person for that contact
* View senders again

### Heuristics
* Scan the senders in the Sent folder
* Offer these as obsolete synonyms for the account holder

### Manual
* Drag and drop within the tag cloud

## Update Messages
* Scan all the gmail addresses, delete if not in All

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
