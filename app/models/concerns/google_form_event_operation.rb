require 'google/apis/sheets_v4'

module GoogleFormEventOperation
  def self.get_google_sheet_service(refresh_token:, access_token: nil)
    sheet_service = Google::Apis::SheetsV4::SheetsService.new
    sheet_service.authorization = GoogleOauth2Client.oauth2_client(refresh_token: refresh_token, access_token: access_token)
    return sheet_service
  end

  def self.load_and_imoport_events!(event_clazz:, refresh_token:, access_token: nil)
    service = self.get_google_sheet_service(refresh_token: refresh_token, access_token: access_token)
    target_spreadsheet = service.get_spreadsheet(event_clazz.google_form_spreadsheet_id, fields: 'sheets.data.rowData.values(formattedValue,userEnteredValue,effectiveValue)')
    target_spreadsheet.sheets.each do |sheet|
      sheet.data.each do |sheet_data|
        # urlがかぶるものは無視する
        import_url_events = {}
        row_data = sheet_data.row_data
        # 1行目はそれぞれの名前に対応するカラム名をあてはめていく
        header_names = (row_data[0].try(:values) || [])
        column_header_names = (header_names[1..(header_names.size)] || []).map{|name_property| name_property.formatted_value.downcase }
        rows = row_data[1..(row_data.size - 1)] || []
        rows.each do |row|
          columns = row.values[1..(row.values.size - 1)]
          event = event_clazz.new
          columns.each_with_index do |column, index|
            next if column.formatted_value.nil?
            event.send(column_header_names[index] + "=", Sanitizer.basic_sanitize(column.formatted_value))
          end
          import_url_events[event.url] = event
        end
        exists_url_events = event_clazz.base_class.where(url: import_url_events.keys).index_by(&:url)
        import_url_events.each do |url, event|
          prev_event = exists_url_events[url]
          if prev_event.present?
            new_attrs = event.attributes
            new_attrs.delete_if {|key, val| val.blank? }
            prev_event.merge_event_attributes(attrs: new_attrs)
            save_event = prev_event
          else
            event.build_location_data
            save_event = event
          end
          save_event.transaction do
            save_event.save!
            save_event.import_hashtags!(hashtag_strings: save_event.search_hashtags)
          end
        end
      end
    end
  end
end