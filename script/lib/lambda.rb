require_relative 'shell'

module Lambda
  def self.create_function(function_name, package_path, runtime, role_arn, handler)
    zip_path = "fileb://#{package_path}"
    status, output = Shell.capture(
      'aws',
      'lambda',
      'update-function-code',
      '--function-name', function_name,
      '--zip-file', zip_path)

    return if status.success?
    unless output.include?('ResourceNotFoundException')
      raise "update-function-code command failed: output=[#{output}] status=[#{status}]"
    end

    Shell.check_capture(
      'aws',
      'lambda',
      'create-function',
      '--function-name', function_name,
      '--zip-file', zip_path,
      '--runtime', runtime,
      '--role', role_arn,
      '--handler', handler,
      '--memory-size', 1024)
  end
end
