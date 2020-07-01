## The contents of this file are subject to the Mozilla Public License
## Version 1.1 (the "License"); you may not use this file except in
## compliance with the License. You may obtain a copy of the License
## at https://www.mozilla.org/MPL/
##
## Software distributed under the License is distributed on an "AS IS"
## basis, WITHOUT WARRANTY OF ANY KIND, either express or implied. See
## the License for the specific language governing rights and
## limitations under the License.
##
## The Original Code is RabbitMQ.
##
## The Initial Developer of the Original Code is GoPivotal, Inc.
## Copyright (c) 2007-2020 VMware, Inc. or its affiliates.  All rights reserved.

defmodule RabbitMQ.CLI.Core.Input do
  alias RabbitMQ.CLI.Core.Config

  def consume_single_line_string_with_prompt(prompt, opts) do
    val = case Config.output_less?(opts) do
      true  ->
        IO.read(:stdio, :line)
      false ->
        IO.puts(prompt)
        IO.read(:stdio, :line)
    end

    case val do
      :eof -> :eof
      ""   -> :eof
      s    -> String.trim(s)
    end
  end

  def consume_multiline_string() do
    val = IO.read(:stdio, :all)

    case val do
      :eof -> :eof
      ""   -> :eof
      s    -> String.trim(s)
    end
  end

  def infer_password(prompt, opts) do
    consume_single_line_string_with_prompt(prompt, opts)
  end
end
