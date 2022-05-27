bundle exec jekyll build --drafts
aws s3 sync ./_site s3://agilogy-blog-staging/ 
