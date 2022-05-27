# Description of the _clickops_ initial setup

1. [Create an IAM user account and create access key and secret](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-prereqs.html)
  - [Configure the access key in a named profile](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-profiles.html) called agilogy

2. Create the s3 bucket:

  - Found [this tutorial](https://blog.eq8.eu/til/create-aws-s3-bucket-as-static-website-with-cli.html)

  ```shell
  aws s3api create-bucket --bucket agilogy-blog-staging --region eu-west-1  --create-bucket-configuration LocationConstraint=eu-west-1
  aws s3api put-bucket-policy --bucket agilogy-blog-staging --policy file://_doc/initialSetup/agilogy-blog-staging-bucket-policy.json
  aws s3 website s3://agilogy-blog-staging/ --index-document index.html --error-document error.html
  ```

3. Upload content:

  ```shell
  bundle exec jekyll build
  aws s3 sync ./_site s3://agilogy-blog-staging/
  ```