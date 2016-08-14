## The contents of this file are subject to the Mozilla Public License
## Version 1.1 (the "License"); you may not use this file except in
## compliance with the License. You may obtain a copy of the License
## at http://www.mozilla.org/MPL/
##
## Software distributed under the License is distributed on an "AS IS"
## basis, WITHOUT WARRANTY OF ANY KIND, either express or implied. See
## the License for the specific language governing rights and
## limitations under the License.
##
## The Original Code is RabbitMQ.
##
## The Initial Developer of the Original Code is Pivotal Software, Inc.
## Copyright (c) 2016 Pivotal Software, Inc.  All rights reserved.

alias RabbitMQ.CLI.Ctl.Validators, as: Validators
alias RabbitMQ.CLI.Distribution,   as: Distribution

defmodule RabbitMQ.CLI.Ctl.Commands.ForgetClusterNodeCommand do
  import RabbitMQ.CLI.Coerce

  @behaviour RabbitMQ.CLI.CommandBehaviour

  def flags, do: [:offline]
  def switches(), do: [offline: :boolean]
  def aliases(), do: []

  def merge_defaults(args, opts) do
    {args, Map.merge(%{offline: false}, opts)}
  end

  def validate([], _),  do: {:validation_failure, :not_enough_args}
  def validate([_,_|_], _),   do: {:validation_failure, :too_many_args}
  def validate([_node_to_remove] = args, %{offline: true} = opts) do
    Validators.chain([&Validators.node_is_not_running/2,
                      &Validators.mnesia_dir_is_set/2,
                      &Validators.rabbit_is_loaded/2],
                     [args, opts])
  end
  def validate([_], %{offline: false}) do
    :ok
  end

  def run([node_to_remove], %{node: node_name, offline: true}) do
    become(node_name)
    :rabbit_mnesia.forget_cluster_node(to_atom(node_to_remove), true)
  end

  def run([node_to_remove], %{node: node_name, offline: false}) do
    :rabbit_misc.rpc_call(node_name,
                          :rabbit_mnesia, :forget_cluster_node,
                          [to_atom(node_to_remove), false])
  end

  def usage() do
    "forget_cluster_node [--offline] <existing_cluster_member_node>"
  end

  def banner([node_to_remove], _) do
    "Removing node #{node_to_remove} from the cluster"
  end


  defp become(node_name) do
    :error_logger.tty(false)
    case :net_adm.ping(node_name) do
        :pong -> exit({:node_running, node_name});
        :pang -> ok = :net_kernel.stop()
                 IO.puts("  * Impersonating node: #{node_name}...")
                 {:ok, _} = Distribution.start_as(node_name)
                 IO.puts(" done")
                 dir = :mnesia.system_info(:directory)
                 IO.puts("  * Mnesia directory: #{dir}", [dir])
    end
  end
end
