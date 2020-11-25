# typed: ignore
# frozen_string_literal: true

require 'open3'

module TypeCheck
  def type_check(code)
    command = %w[bundle exec srb typecheck]
    command.concat(["-e", code])
    _out, err, st = Open3.capture3(*command)
    return if st.success?

    puts(CodeRay.scan(code, :ruby).term)
    puts(err)
    raise("Generated code failed type checking.")
  end
end
