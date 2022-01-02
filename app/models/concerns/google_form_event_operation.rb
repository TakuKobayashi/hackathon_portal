require 'google/apis/sheets_v4'

module GoogleFormEventOperation
  def self.load_and_imoport_events!(refresh_token: ENV.fetch('GOOGLE_OAUTH_BOT_REFRESH_TOKEN', ''), target_spreadsheet_id: HackathonEvent.google_form_spreadsheet_id)
    service = GoogleServices.get_sheet_service(refresh_token: refresh_token)
    target_spreadsheet =
      service.get_spreadsheet(
        target_spreadsheet_id,
        fields: 'sheets.data.rowData.values(formattedValue,userEnteredValue,effectiveValue)',
      )

    script_service = GoogleServices.get_script_service(refresh_token: refresh_token)
    script_deployments = script_service.list_project_deployments(ENV.fetch('LOCATION_GAS_SCRIPT_ID', ''))
    latest_deployment = script_deployments.deployments.max_by { |d| d.deployment_config.version_number.to_i }
    script_url = latest_deployment.entry_points.first.try(:web_app).try(:url)

    target_spreadsheet.sheets.each do |sheet|
      sheet.data.each do |sheet_data|
        # urlがかぶるものは無視する
        import_url_events = {}
        row_data = sheet_data.row_data

        # 1行目はそれぞれの名前に対応するカラム名をあてはめていく
        header_names = (row_data[0].try(:values) || [])
        column_header_names =
          (header_names[1..(header_names.size)] || []).map { |name_property| name_property.formatted_value.downcase }
        rows = row_data[1..(row_data.size - 1)] || []
        rows.each do |row|
          columns = row.values[1..(row.values.size - 1)]
          event = Event.new
          columns.each_with_index do |column, index|
            next if column.formatted_value.nil?
            event.send(column_header_names[index] + '=', Sanitizer.basic_sanitize(column.formatted_value))
          end
          import_url_events[event.url] = event
        end
        exists_url_events = Event.where(url: import_url_events.keys).index_by(&:url)
        import_url_events.each do |url, event|
          prev_event = exists_url_events[url]
          if prev_event.present?
            new_attrs = event.attributes
            new_attrs.delete_if { |key, val| val.blank? }
            prev_event.merge_event_attributes(attrs: new_attrs)
            save_event = prev_event
          else
            event.build_location_data(script_url: script_url) if script_url.present?
            save_event = event
          end
          save_event.informed_from = :google_form
          save_event.transaction do
            save_event.save!
            save_event.import_hashtags!(hashtag_strings: save_event.search_hashtags)
          end
        end
      end
    end
  end
end
