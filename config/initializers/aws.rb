# frozen_string_literal: true

require "aws-sdk-s3"

Aws.config[:s3] = { region: Figaro.env.AWS_REGION, endpoint: Figaro.env.S3_ENDPOINT }
