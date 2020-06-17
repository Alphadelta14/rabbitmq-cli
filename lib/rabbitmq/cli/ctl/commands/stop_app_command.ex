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

defmodule RabbitMQ.CLI.Ctl.Commands.StopAppCommand do
  @behaviour RabbitMQ.CLI.CommandBehaviour

  use RabbitMQ.CLI.Core.MergesNoDefaults
  use RabbitMQ.CLI.Core.AcceptsNoPositionalArguments

  def run([], %{node: node_name}) do
    :rabbit_misc.rpc_call(node_name, :rabbit, :stop, [])
  end

  use RabbitMQ.CLI.DefaultOutput

  def usage, do: "stop_app"

  def help_section(), do: :node_management

  def description(), do: "Stops the RabbitMQ application, leaving the runtime (Erlang VM) running"

  def banner(_, %{node: node_name}), do: "Stopping rabbit application on node #{node_name} ..."
end
