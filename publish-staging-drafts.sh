bundle exec jekyll clean
bundle exec jekyll build --drafts 
aws s3 sync ./_site s3://agilogy-blog-staging/ 
open http://agilogy-blog-staging.s3-website-eu-west-1.amazonaws.com/
