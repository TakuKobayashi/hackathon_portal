# ハッカソンポータル

## 紹介

新着のハッカソン・ゲームジャム・アイディアソン・開発合宿の情報を自動的にお知らせしているBotです。
よかったらフォローしてください!!

 * Twitter: http://bit.ly/2O1gmYi
 * Qiita: http://bit.ly/2CyqzWH
 * Blogger: http://bit.ly/2CuDGIw
 * Googleカレンダー: http://bit.ly/34Y359T


ここではその処理の中身を公開しています。

## 解説

QiitaやBloggerの方がよりまとまった情報として紹介しています。
カレンダーの形としてGoogleカレンダーにても公開されています。
現在は日本より参加できる情報を中心に紹介しています。
海外でのイベント情報もOnlineにて開催されているものも紹介していますので、海外のオンラインイベントにも参加してみてください。

## 情報を集めているサービス

 * [Connpass](https://connpass.com/)
 * [Doorkeeper](https://www.doorkeeper.jp/)
 * [Peatix](https://peatix.com/)
 * [Twitter](https://twitter.com/search?q=hackathon%20OR%20%E3%83%83%E3%82%AB%E3%82%BD%E3%83%B3%20OR%20gamejam%20OR%20%E3%82%A2%E3%82%A4%E3%83%87%E3%82%A3%E3%82%A2%E3%82%BD%E3%83%B3%20OR%20%E3%82%A2%E3%82%A4%E3%83%87%E3%82%A2%E3%82%BD%E3%83%B3%20OR%20ideathon%20OR%20%E9%96%8B%E7%99%BA%E5%90%88%E5%AE%BF%20OR%20%E3%81%AF%E3%81%A3%E3%81%8B%E3%81%9D%E3%82%93&src=typed_query&f=live)
 * [Devpost](https://devpost.com/hackathons)

このほかに追加で収集してほしいサービスとかありましたら、issueなどで述べてください。

## 技術的なお話

Gitlab CI Runnerを使い、一定の時刻になると自動的に情報を集め始めます。
情報を集めた後にそれぞれのアカウントに投稿しています。
タイトルや詳細文からハッカソンに関するものなのかどうか推測し、判断した上で投稿するようにしています。
.envの中にapikeyやアクセストークンなどの詳細な情報を記載しています。流用したい場合などは、.env.sampleを.envに改名して、必要な情報を入力して実行してください。
実行コマンドについては[.gitlab-ci.yml](./.gitlab-ci.yml)にて記載していますのでそちらを参照してください。