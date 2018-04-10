#!/usr/bin/env ruby
require 'json'
require 'yaml'
require_relative 'lib/s3'
require_relative 'lib/shell'

def transform(obj, &block)
  if obj.is_a?(Hash)
    temp = {}
    obj.each do |k, v|
      temp[transform(k, &block)] = transform(v, &block)
    end
    temp
  elsif obj.is_a?(Array)
    obj.map { |item| transform(item, &block) }
  else
    block.call(obj)
  end
end

def main
  this_dir = File.expand_path('..', __FILE__)
  config_yaml_path = File.expand_path('config.yaml', this_dir)

  config = YAML.load(File.read(config_yaml_path))
  s3_web_site = config.fetch('s3-web-site')
  bucket_name = s3_web_site.fetch('bucket')
  values = {
    bucket: bucket_name
  }
  bucket_policy = transform(s3_web_site.fetch('bucket-policy')) do |v|
    v.is_a?(String) ? v % values : v
  end

  index_document = s3_web_site.fetch('index-document')
  error_document = s3_web_site.fetch('error-document')
  source_dir = s3_web_site.fetch('source-dir')

  S3.create_bucket bucket_name
  S3.put_bucket_policy bucket_name, bucket_policy
  S3.website bucket_name, index_document, error_document
  config_yaml_dir = File.dirname(config_yaml_path)
  s3_web_site.fetch('files').each do |file|
    key = file.fetch('key')
    local_path = File.expand_path(File.join(source_dir, file.fetch('local-path')), config_yaml_dir)
    content_type = file.fetch('content-type')
    S3.put_object bucket_name, key, local_path, content_type
  end
end
main