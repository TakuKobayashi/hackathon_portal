require 'google/apis/sheets_v4'

module GoogleFormEventOperation
  def self.load_and_imoport_events_and_clear_sheet!(
    refresh_token: ENV.fetch('GOOGLE_OAUTH_BOT_REFRESH_TOKEN', ''),
    target_spreadsheet_id: HackathonEvent.google_form_spreadsheet_id
  )
    service = GoogleServices.get_sheet_service(refresh_token: refresh_token)
    target_spreadsheet =
      service.get_spreadsheet(
        target_spreadsheet_id,
        fields: 'sheets.data.rowData.values(formattedValue,userEnteredValue,effectiveValue)',
      )
    script_url = GoogleServices.get_location_script_url(refresh_token: refresh_token)
    target_spreadsheet.sheets.each do |sheet|
      sheet.data.each do |sheet_data|
        row_data = sheet_data.row_data

        event_attr_values = self.constract_event_attrs_from_sheet(row_data: row_data)
        current_url_events = Event.where(url: event_attr_values.map(&:url)).includes(:event_detail).index_by(&:url)
        event_attr_values.each do |event_attr|
          Event.transaction do
            if current_url_events[event_attr.url].present?
              event = current_url_events[event_attr.url]
            else
              event = Event.new(url: event_attr.url)
            end
            event.merge_event_attributes(attrs: { state: :active, informed_from: :google_form }.merge(event_attr.to_h))
            event.save!
            event.import_hashtags!(hashtag_strings: event.search_hashtags)
          end
        end
        self.clear_spreadsheet(
          refresh_token: refresh_token,
          target_spreadsheet_id: target_spreadsheet_id,
          row_count: [row_data.size - 1, 0].max,
          column_count: row_data.first.try(:values).try(:size).to_i,
        )
      end
    end
  end

  def self.clear_spreadsheet(
    refresh_token: ENV.fetch('GOOGLE_OAUTH_BOT_REFRESH_TOKEN', ''),
    target_spreadsheet_id: HackathonEvent.google_form_spreadsheet_id,
    row_count:,
    column_count:
  )
    service = GoogleServices.get_sheet_service(refresh_token: refresh_token)
    clear_values =
      row_count.times.map do |rc|
        column_array = Array.new(column_count)
        column_array.fill('')
      end
    if clear_values.present?
      service.update_spreadsheet_value(
        target_spreadsheet_id,
        'A2',
        Google::Apis::SheetsV4::ValueRange.new(values: clear_values),
        value_input_option: 'USER_ENTERED',
      )
    end
  end

  private

  def self.constract_event_attrs_from_sheet(row_data:)
    # 1行目はそれぞれの名前に対応するカラム名をあてはめていく
    header_values = (row_data[0].try(:values) || [])
    column_names = header_values.map { |name_property| name_property.formatted_value.downcase }
    event_attr_values = []
    row_data.each_with_index do |row, row_index|
      next if row_index == 0
      next if row.values.blank?
      event_attr = OpenStruct.new
      row.values.each_with_index do |row_value, index|
        next if index == 0 || index == row.values.size - 1
        event_attr.send(column_names[index] + '=', row_value.formatted_value)
      end

      # addressが空欄だったらオンラインイベントとする
      event_attr.place = 'online' if event_attr.address.blank?
      event_attr_values << event_attr
    end
    return event_attr_values
  end
end
