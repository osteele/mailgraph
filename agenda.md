# Next
* Consolidate addresses
* Tag cloud
* Update messages; sweep the cache
* Select year
* Switch between senders and recipients
* Incremental update
  test whether UIDNEXT has incremented?

## Public
* Scan more mailboxes, if All is not present
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

## Consolidate Addresses
### Contacts
* test for attr["primary"]=="true"; store primary contact address
* Canonicalization: for each email address that has only one contact, use that contact's primary address

### Heuristics
* Scan the senders in the Sent folder
* Offer these as obsolete synonyms for the account holder

### Manual
* Drag and drop within the tag cloud

## Update Messages
* Scan all the gmail addresses, delete if not in All

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
