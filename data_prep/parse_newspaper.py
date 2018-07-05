from newspaper import Article
import nltk
import sys
import json

# Prepare/parse article
def parse_article(url):
    article = Article(url)
    article.download()
    article.parse()
    article.nlp()
    gen_article_dictionary(article)

# Dictionary with article details
def gen_article_dictionary(article):
    article_dictionary = {
        'authors': article.authors,
        'publish_date': str(article.publish_date),
        'article_text': article.text,
        'article_keywords': article.keywords,
        'article_summary': article.summary}
    print(json.dumps(article_dictionary, ensure_ascii=True))

parse_article(sys.argv[1])
