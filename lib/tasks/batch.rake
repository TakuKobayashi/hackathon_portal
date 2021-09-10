require 'google/apis/calendar_v3'
require 'googleauth'
require 'googleauth/stores/file_token_store'
require 'google/apis/slides_v1'

require 'fileutils'

namespace :batch do
  task event_bot_tweet: :environment do
    will_post_events =
      Event
        .where.not(type: nil)
        .where('? < started_at AND started_at < ? AND ? < ended_at', 1.year.ago, 1.year.since, Time.current)
        .order('started_at ASC')

    # 既に終わってしまっていることがわかるようなイベントは取り除く
    future_events = []
    will_post_events.each do |event|
      # Activeではないものは除外
      next unless event.active?

      # これから始まるものだけ選別する
      next if event.started_at < Time.current

      # これから始まるものだけ選別する
      if event.url_active?
        future_events << event
      else
        event.closed!
      end
    end
    Event.preset_tweet_urls!(events: will_post_events)

    future_events.each do |event|
      if !TwitterBot.exists?(from: event)
        tweet_options = { lat: event.lat, long: event.lon }
        TwitterBot.tweet!(
          text: event.generate_tweet_text,
          access_token: ENV.fetch('TWITTER_BOT_ACCESS_TOKEN', ''),
          access_token_secret: ENV.fetch('TWITTER_BOT_ACCESS_TOKEN_SECRET', ''),
          from: event,
          options: tweet_options,
        )
      end
    end
    QiitaBot.post_or_update_article!(events: will_post_events, access_token: ENV.fetch('QIITA_BOT_ACCESS_TOKEN', ''))
    future_events.each do |future_event|
      EventCalendarBot.insert_or_update_calender!(
        event: future_event,
        refresh_token: ENV.fetch('GOOGLE_OAUTH_BOT_REFRESH_TOKEN', ''),
      )
    end
    BloggerBot.post_or_update_article!(
      events: will_post_events,
      blogger_blog_url: 'https://hackathonportal.blogspot.com/',
      refresh_token: ENV.fetch('GOOGLE_OAUTH_BOT_REFRESH_TOKEN', ''),
    )
  end

  task generate_slide: :environment do
    service = Google::Apis::SlidesV1::SlidesService.new
    service.authorization =
      GoogleOauth2Client.oauth2_client(refresh_token: ENV.fetch('GOOGLE_OAUTH_BOT_REFRESH_TOKEN', ''))
    presentation = Google::Apis::SlidesV1::Presentation.new(title: 'slide_name')
    new_presentation = service.create_presentation(presentation)

    create_slide = Google::Apis::SlidesV1::CreateSlideRequest.new
    request = Google::Apis::SlidesV1::Request.new(create_slide: create_slide)
    batch = Google::Apis::SlidesV1::BatchUpdatePresentationRequest.new(requests: [request])
    batch.update!(requests: [request])
    service.batch_update_presentation(new_presentation.presentation_id, batch, {})
  end

  task export_entity_relationship_diagram_plantuml: :environment do
    # 使用されている全てのテーブルのModelの情報を取得するために全て読み込む
    Rails.application.eager_load!

    # 使用されている全てのテーブルを持っていて関係性がわかるModelの情報を取得する
    model_classes = ActiveRecord::Base.descendants.select { |m| m.table_name.present? }
    class_name_model_class_pair = model_classes.index_by(&:to_s)
    relation_entity_components = Set.new
    entity_component_fields = Set.new
    unique_index_table_columns = Set.new
    foreign_key_pairs = {}

    # ER図においてそれぞれのエンティティとの関連性を記述していく
    class_name_model_class_pair.values.each do |model_class|
      model_class
        .reflections
        .values
        .each do |relation_info|
          # polymorphic の belongs_to の構造はリレーション関係がわからないのでスルー
          next if relation_info.polymorphic?

          # belongs_to 参照元を取得する場合はfrom と toの対象を交換する
          if relation_info.instance_of?(ActiveRecord::Reflection::BelongsToReflection)
            to_model_class = model_class
            from_model_class = class_name_model_class_pair[relation_info.class_name]
          else
            from_model_class = model_class
            to_model_class = class_name_model_class_pair[relation_info.class_name]
          end
          primary_keys = [from_model_class.primary_key].flatten
          to_foreign_key_string = [to_model_class.table_name, relation_info.foreign_key].join('.')
          if relation_info.options[:primary_key].present?
            from_foreign_key_string = [from_model_class.table_name, relation_info.options[:primary_key]].join('.')
          else
            from_foreign_key_string =
              primary_keys.map { |primary_key| [from_model_class.table_name, primary_key].join('.') }.join(',')
          end

          # 外部キーのカラムとの関係性を記録する
          foreign_key_pairs[to_foreign_key_string] = from_foreign_key_string

          # has_many 関係性を表現 1対多の場合
          if relation_info.instance_of?(ActiveRecord::Reflection::HasManyReflection)
            # 0 ~ 複数
            relation_entity_components << [from_model_class.table_name, '--o{', to_model_class.table_name].join(' ')
            # has_one 関係性を表現 1対1の場合
          elsif relation_info.instance_of?(ActiveRecord::Reflection::HasOneReflection)
            # belongs_toの要素が先に登録されていたら消す
            relation_entity_components.delete(
              [from_model_class.table_name, '--o{', to_model_class.table_name].join(' '),
            )

            # 0 ~ 1
            relation_entity_components << [from_model_class.table_name, '|o--o|', to_model_class.table_name].join(' ')
            # has_many :through 関係性を表現 多対多の場合
          elsif relation_info.instance_of?(ActiveRecord::Reflection::ThroughReflection)
            relation_entity_components << [from_model_class.table_name, '}o--o{', to_model_class.table_name].join(' ')
            # belongs_to 参照元を取得 とりあえず 1対多として記録
          elsif relation_info.instance_of?(ActiveRecord::Reflection::BelongsToReflection)
            # has_one の要素が記録されていたらスキップ
            unless relation_entity_components.include?(
                     [from_model_class.table_name, '|o--o|', to_model_class.table_name].join(' '),
                   )
              relation_entity_components << [from_model_class.table_name, '--o{', to_model_class.table_name].join(' ')
            end
          end
        end

      model_class
        .connection
        .indexes(model_class.table_name)
        .each do |index_definition|
          # unique index(単体)カラムには印をつけるため該当するものを集める
          if index_definition.unique && index_definition.columns.size == 1
            unique_index_table_column = [model_class.table_name, index_definition.columns.first].join('.')
            unique_index_table_columns << unique_index_table_column
          end
        end
    end

    # ER図においてそれぞれのエンティティのカラムの特徴を記述していく
    class_name_model_class_pair.values.each do |model_class|
      primary_keys = [model_class.primary_key].flatten
      entity_components = []
      entity_components << ['entity', '"' + model_class.table_name + '"', '{'].join(' ')
      model_class.columns.each do |model_column|
        table_column_string = [model_class.table_name, model_column.name].join('.')
        if primary_keys.include?(model_column.name)
          entity_components << ['+', model_column.name, '[PK]', model_column.sql_type].join(' ')
          entity_components << '=='
          # 外部キーには目印
        elsif foreign_key_pairs[table_column_string].present?
          entity_components <<
            [
              '#',
              model_column.name,
              '[FK(' + foreign_key_pairs[table_column_string] + ')]',
              model_column.sql_type,
            ].join(' ')
          # unique indexには目印
        elsif unique_index_table_columns.include?(table_column_string)
          entity_components << ['*', model_column.name, model_column.sql_type].join(' ')
        else
          entity_components << [model_column.name, model_column.sql_type].join(' ')
        end
      end
      entity_components << '}'
      entity_components << "\n"
      entity_component_fields << entity_components.join("\n")
    end

    # PlantUMLを記述
    plntuml_components = Set.new
    plntuml_components << '```plantuml'
    plntuml_components << '@startuml'
    plntuml_components += entity_component_fields
    plntuml_components += relation_entity_components
    plntuml_components << '@enduml'
    plntuml_components << '```'
    export_plantuml_path = Rails.root.join('er-diagram.plantuml')
    File.write(export_plantuml_path, plntuml_components.to_a.join("\n"))
  end
end
