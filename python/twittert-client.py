from twitter.scraper import Scraper
from dotenv import load_dotenv
import os
env_path = os.path.join(os.path.dirname(__file__), '../.env')
load_dotenv(env_path)

scraper = Scraper(os.getenv("TWITTER_BOT_ACCOUNT_EMAIL"), os.getenv("TWITTER_BOT_ACCOUNT_USER_NAME"), os.getenv("TWITTER_BOT_ACCOUNT_PASSWORD"))
tweets_by_ids = scraper.tweets_by_id([1689216127233060867, 1688491355431907328])
print(tweets_by_ids)