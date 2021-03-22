# コピペでOK, app_nameもそのままでOK
# 19.01.20現在最新安定版のイメージを取得
FROM ruby:2.7

# 必要なパッケージのインストール（基本的に必要になってくるものだと思うので削らないこと）
RUN apt update -qq && apt install -y build-essential libpq-dev nodejs
RUN apt install -y default-mysql-client

# 作業ディレクトリの作成、設定
RUN mkdir /app

##作業ディレクトリ名をAPP_ROOTに割り当てて、以下$APP_ROOTで参照
ENV APP_ROOT /app
WORKDIR $APP_ROOT

# ホスト側（ローカル）のGemfileを追加する（ローカルのGemfileは【３】で作成）
ADD ./Gemfile $APP_ROOT/Gemfile
ADD ./Gemfile.lock $APP_ROOT/Gemfile.lock

# Gemfileのbundle install
RUN bundle install
ADD . $APP_ROOT
