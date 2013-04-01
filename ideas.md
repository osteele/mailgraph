# Features
* Mute senders
* Recognize mailing lists
* Recognize bulk mail
* Work w/ Google Bulk
* Collect links
* Voice summarization
* Show unreplied messages (incoming, outgoing)
* Graph by geo IP
* Query language, e.g.:

    Incoming unanswered messages from a contact or correspondent.

    SELECT message
    WHERE direction='Incoming'
      AND (sender IN contacts OR (SELECT COUNT(*) FROM sent WHERE sender IN sent.recipient AND date > 1.year.ago) > 0)
      AND (SELECT COUNT(*) FROM sent WHERE message IN in_reply_to)

# Analysis
* Index keywords
* Index by RFC822.SIZE
* Sentiment analysis
* Vocabulary analysis
* MTTR by sender / recipient
* Topics by correspondent

# Presentation
* Tag cloud
  * Add size
  * Show photos //link[rel="http://schemas.google.com/contacts/2008/rel#photo"][type="image/*"].attr('etag')
  * Sort by frequency, name, last contact
  * Filter by sender, recipient, timespan
* Chord diagram of sender -> recipient
* Sankey of senders -> recipients
* Stream graph
  * Filter by sender, recipient, timespan
* More analogs http://betabeers.com/uploads/estudios/crunchbase-startup-data/?
  * Bar char: Incoming vs. Outgoing by year
  * Pie char: Top Senders 2012 [choose year]; Top Recipients 2012
  * Tables: Top correspondents by year [range of years]
* Frequent term wordle https://github.com/jasondavies/d3-cloud
