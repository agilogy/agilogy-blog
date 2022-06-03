bundle exec jekyll clean
bundle exec jekyll build
aws s3 sync ./_site s3://blog.agilogy.com/ 
