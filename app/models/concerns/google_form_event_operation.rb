require 'google/apis/sheets_v4'

module GoogleFormEventOperation
  def self.load_and_imoport_events!(
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
        # urlがかぶるものは無視する
        import_url_events = {}
        row_data = sheet_data.row_data

        # 1行目はそれぞれの名前に対応するカラム名をあてはめていく
        header_values = (row_data[0].try(:values) || [])
        column_names = header_values.map { |name_property| name_property.formatted_value.downcase }
        rows = row_data[1..(row_data.size - 1)] || []
        event_attr_values = rows.map do |row|
          event_attr = OpenStruct.new
          row.values.each_with_index do |row_value, index|
            next if index == 0
            event_attr.send(column_names[index] + "=", row_value.formatted_value)
          end
          # addressが空欄だったらオンラインイベントとする
          if event_attr.address.blank?
            event_attr.place = 'online'
          end
          event_attr
        end
        current_url_events = Event.where(url: event_attr_values.map(&:url)).includes(:event_detail).index_by(&:url)
        event_attr_values.each do |event_attr|
          Event.transaction do
            if current_url_events[event_attr.url].present?
              event = current_url_events[event_attr.url]
            else
              event = Event.new(url: event_attr.url)
            end
            event.merge_event_attributes(
              attrs: {
                state: :active,
                informed_from: :google_form,
              }.merge(event_attr.to_h),
            )
            event.save!
            event.import_hashtags!(hashtag_strings: event.search_hashtags)
          end
        end
      end
    end
  end
end
