class EmailAnalyzer
  attr_reader :account

  def initialize(account)
    @account = account
  end

  def frequent_correspondents(limit=nil)
    limit ||= 15
    account_contact = Contact.for_address_spec(account.email_address, account)
    contacts = Address.find_by_sql([<<-SQL, account.id, account.id, account_contact.id, limit])
      SELECT *, COUNT(*) AS message_count FROM contacts
      JOIN addresses_contacts_view ON addresses_contacts_view.contact_id=contacts.id
      JOIN message_associations ON message_associations.address_id=addresses_contacts_view.address_id
      JOIN messages ON message_associations.message_id=messages.id
      WHERE messages.account_id=? AND contacts.account_id=? AND contacts.id!=?
      GROUP BY contacts.id
      ORDER BY COUNT(*) DESC LIMIT ?
    SQL
    return contacts
  end

  def series(options)
    start_date = options[:start_date] || account.messages.where('date IS NOT NULL AND date > "1975-01-01"').first(:order => :date).date.beginning_of_year
    end_date = options[:end_date] || account.messages.last(:order => 'date').date
    limit = options[:limit]

    unless options[:by_interval]
      account_contact = Contact.for_address_spec(account.email_address, account)
      records = Contact.connection.select_all(<<-SQL, nil, [[nil, account.id], [nil, account_contact.id], [nil, start_date], [nil, end_date], [nil, limit]])
        SELECT *, COUNT(*) AS message_count, contacts_messages_view.address
        FROM contacts_messages_view
        JOIN messages ON contacts_messages_view.message_id=messages.id
        WHERE contacts_messages_view.account_id = $1 AND contacts_messages_view.contact_id != $2
        AND $3 < messages.date AND messages.date < $4
        GROUP BY contacts_messages_view.contact_id, field
        ORDER BY message_count DESC
        LIMIT $5
      SQL
      summaries = {}
      current_summary = nil
      records.each do |record|
        current_summary = summaries[record['contact_id']] ||= {
            :id => record['contact_id'],
            :address => record['address'],
            :name => record['name'],
            :fields => {},
            :value => 0
          }
        current_summary[:fields][record['field']] = record['message_count']
        current_summary[:value] += record['message_count']
      end
      return summaries.values
    end

    stats = {}
    map = {}
    account_address = Address.find_by_spec(account.email_address).canonicalize
    while start_date < end_date
      next_date = start_date + 1.month
      results = Message.connection.select_all(<<-SQL, nil, [[nil, account.id], [nil, start_date], [nil, next_date], [nil, account_address.id]])
        SELECT spec, addresses.id, addresses.canonical_address_id, COUNT(*) AS count
        FROM addresses
        JOIN message_associations ON address_id=addresses.id
        JOIN messages ON message_id=messages.id
        WHERE messages.account_id = $1 AND $2 <= messages.date AND messages.date < $3
        AND domain_name IS NOT NULL
        AND addresses.id != $4 AND (canonical_address_id IS NULL OR canonical_address_id != $4)
        GROUP BY (CASE WHEN canonical_address_id IS NOT NULL THEN canonical_address_id ELSE addresses.id END)
        ORDER BY COUNT(*) DESC
        LIMIT 15
      SQL
      for record in results
        record["spec"] = map[record["canonical_address_id"]] ||= Address.find(record["canonical_address_id"]).spec if record["canonical_address_id"] and record["canonical_address_id"] != record["id"]
      end
      stats[start_date.strftime("%Y-%m")] = results.inject({}) { |h, r| h[r["spec"].to_s] = r["count"]; h }
      start_date = next_date
    end
    names = stats.map { |date, counts| counts.keys }.flatten.uniq
    names = names.inject({}) do |h, name|
      h[name] = stats.map { |_, x| x[name] }.compact.sum
      h
    end.to_a.sort { |a, b| b[1] <=> a[1] }[0...limit].map { |name, _| name }
    series = names.map do |name|
      {
        :key => name,
        :values => stats.map { |date, x| {date: date, count: x[name] || 0} }
      }
    end
    return series
  end
end
