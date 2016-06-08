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
## The Initial Developer of the Original Code is GoPivotal, Inc.
## Copyright (c) 2007-2016 Pivotal Software, Inc.  All rights reserved.


defmodule ReportTest do
  use ExUnit.Case, async: false
  import TestHelper

  setup_all do
    RabbitMQCtl.start_distribution(%{})
    :net_kernel.connect_node(get_rabbit_hostname)

    on_exit([], fn ->
      :erlang.disconnect_node(get_rabbit_hostname)
      :net_kernel.stop()
    end)

    :ok
  end

  setup do
    {:ok, opts: %{node: get_rabbit_hostname, timeout: :infinity}}
  end

  test "validate: with extra arguments, status returns an arg count error", context do
    assert ReportCommand.validate(["extra"], context[:opts]) ==
    {:validation_failure, :too_many_args}
  end

  test "run: report request on a named, active RMQ node is successful", context do
    assert match?([_|_], ReportCommand.run([], context[:opts]))
  end

  test "run: report request on nonexistent RabbitMQ node returns nodedown" do
    target = :jake@thedog
    :net_kernel.connect_node(target)
    opts = %{node: target}
    assert match?({:badrpc, _}, ReportCommand.run([], opts))
  end

  test "banner", context do
    assert ReportCommand.banner([], context[:opts])
      =~ ~r/Reporting server status of node #{get_rabbit_hostname}/
  end
end
