class EmailAnalyzer
  attr_reader :account

  def initialize(account)
    @account = account
  end

  def frequent_correspondents(limit=nil)
    limit ||= 15
    account_contact = Contact.for_address_spec(account.email_address, account)
    # raise [account.id, account_contact.id, account_contact].inspect
    contacts = Address.find_by_sql([<<-"SQL", account.id, account_contact.id, limit])
      SELECT *, COUNT(*) AS message_count FROM contacts
      JOIN computed_addresses_contacts ON computed_addresses_contacts.contact_id=contacts.id
      JOIN message_associations ON message_associations.address_id=computed_addresses_contacts.address_id
      JOIN messages ON message_associations.message_id=messages.id
      WHERE messages.account_id = ? AND contacts.id != ?
      GROUP BY contacts.id
      ORDER BY COUNT(*) DESC LIMIT ?
    SQL
    # raise contacts.map(&:message_count).inspect
    return contacts

    addresses = Address.find_by_sql([<<-"SQL", self.id, account_address.id, limit])
      SELECT (CASE WHEN canonical_address_id IS NOT NULL THEN canonical_address_id ELSE addresses.id END) AS id, COUNT(*) AS count
      FROM addresses
      JOIN message_associations ON address_id=addresses.id
      JOIN messages ON message_id=messages.id
      WHERE messages.account_id = ?
      AND domain_name IS NOT NULL
      AND (canonical_address_id IS NULL OR canonical_address_id != ?)
      GROUP BY addresses.id
      ORDER BY COUNT(*) DESC
      LIMIT ?
    SQL
    Address.find(addresses.map(&:id))
  end

  def series(start_date, end_date, limit)
    start_date ||= account.messages.where('date IS NOT NULL AND date > "1975-01-01"').first(:order => :date).date.beginning_of_year
    end_date ||= account.messages.last(:order => 'date').date
    stats = {}
    map = {}
    account_address = Address.find_by_spec(account.email_address).canonicalize
    while start_date < end_date
      next_date = start_date + 1.month
      results = Message.connection.select_all(<<-"SQL", nil, [[nil, user.id], [nil, start_date], [nil, next_date], [nil, account_address.id]])
        SELECT spec, addresses.id, addresses.canonical_address_id, COUNT(*) AS count FROM addresses
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
