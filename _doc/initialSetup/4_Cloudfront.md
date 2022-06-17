# Configure the Cloudfront distribution

## Description

- Context:
  - Our DNSs are handled by AWS Route 53
  - The blog was deployed in a S3 bucket served as a static website
  - We want to serve the blog with Amazon CloudFront as a CDN and under HTTPs
- Decissions taken:
  - We will use AWS Certificate Manager to create a certificate for us. This has the advantage that Amazon automatically handles the renewal of the certificate for us

### Clickops script

1. Create a certificate for blog.agilogy.com
2. Create a Cloudfront distribution

### Create a certificate 

For the certificate to be usable by CloudFront, it _"must be in the US East (N. Virginia) Region (us-east-1)"_.

1. Go to the [Certificates Manager](https://us-east-1.console.aws.amazon.com/acm/home) console in N. Virginia
2. Click _Request_
3. Select _Request a public certificate_ and click _Next_
4. Fully qualified domain name: blog.agilogy.com
5. Select _DNS Validation_ (already the default value) and cilck _Request_
6. Under domains, click _Create records in Route 53_ to automatically create the CNAME record that will validate the domain for this certificate
7. Wait some minutes until the domain status becomes ✅ _Success_

### Create a CLoudFront distribution

1. Go to the [CloudFront console](https://us-east-1.console.aws.amazon.com/cloudfront/v3/home)
2. Select Create Distribution
3. Get the bucket websitte hosting url of the S3 bucket containing the blog
   1. In a new tab, go to S3 console
   2. Select the bucket [blog.agilogy.com](https://s3.console.aws.amazon.com/s3/buckets/blog.agilogy.com?region=us-east-1)
   3. Go to _Properties_ tab, _Static website hosting_ section
   4. Copy the value under _Bucket website endpoint_
4. Origin domain: Paste the copied value
5. Name: blog.agilogy.com
6. Viewer protocol policy: Redirect HTTP to HTTPS
7. Alternate domain name (CNAME): Add Item `blog.agilogy.com`
8. Custom SSL certificate: Select blog.agilogy.com under ACM certificates
9. Cilck _Create Distribution_
10. Under _General_ / _Details_ copy the _Distribution domain name_ value to configure the DNS next

### Configure the DNS

1. Go to the [Route 53 Console](https://us-east-1.console.aws.amazon.com/route53/v2/home#Dashboard)
2. Click _Hosted zones_ under _Route 53 Dashboard_
3. Select agilogy.com
4. Click _Create record_
5. Select _Simple Record_ (already selected by default) and click _Next_
6. Click _Define simple record_
7. Record name: blog.agilogy.com
8. Record type: CNAME
9. Value / Route traffic to: _IP address or another value..._ / the distribution domain name you just copied
10. Click _Define simple record_
11. Click _Create records_

## Sources

- https://aws.amazon.com/premiumsupport/knowledge-center/cloudfront-https-requests-s3/