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


defmodule ListPoliciesCommandTest do
  use ExUnit.Case, async: false
  import TestHelper

  @command RabbitMQ.CLI.Ctl.Commands.ListPoliciesCommand

  @vhost "test1"
  @user "guest"
  @root   "/"
  @key "federate"
  @pattern "^fed\."
  @value "{\"federation-upstream-set\":\"all\"}"
  @apply_to "all"
  @priority 0

  setup_all do
    RabbitMQ.CLI.Distribution.start()
    :net_kernel.connect_node(get_rabbit_hostname)

    add_vhost @vhost

    enable_federation_plugin()

    on_exit(fn ->
      delete_vhost @vhost
      :erlang.disconnect_node(get_rabbit_hostname)
      :net_kernel.stop()
    end)

    :ok
  end

  def enable_federation_plugin() do
    node = get_rabbit_hostname

    {:ok, plugins_file} = :rabbit_misc.rpc_call(node,
                                                :application, :get_env,
                                                [:rabbit, :enabled_plugins_file])
    {:ok, plugins_dir} = :rabbit_misc.rpc_call(node,
                                               :application, :get_env,
                                               [:rabbit, :plugins_dir])
    {:ok, rabbitmq_home} = :rabbit_misc.rpc_call(node, :file, :get_cwd, [])

    {:ok, [enabled_plugins]} = :file.consult(plugins_file)

    opts = %{enabled_plugins_file: plugins_file,
             plugins_dir: plugins_dir,
             rabbitmq_home: rabbitmq_home,
             online: true, offline: false}

    plugins = currently_active_plugins(%{opts: %{node: node}})
    case Enum.member?(plugins, :rabbitmq_federation) do
      true  -> :ok
      false ->
        set_enabled_plugins(get_rabbit_hostname, plugins ++ [:rabbitmq_federation], opts)
    end
  end

  setup context do

    on_exit(fn ->
      clear_policy context[:vhost], context[:key]
    end)

    {
      :ok,
      opts: %{
        node: get_rabbit_hostname,
        timeout: (context[:timeout] || :infinity),
        vhost: context[:vhost],
        apply_to: @apply_to,
        priority: 0
      }
    }
  end

  test "validate: providing too many arguments fails validation" do
    assert @command.validate(["many"], %{}) == {:validation_failure, :too_many_args}
    assert @command.validate(["too", "many"], %{}) == {:validation_failure, :too_many_args}
    assert @command.validate(["this", "is", "too", "many"], %{}) == {:validation_failure, :too_many_args}
  end

  @tag key: @key, pattern: @pattern, value: @value, vhost: @vhost
  test "run: a well-formed, host-specific command returns list of policies", context do
    vhost_opts = Map.merge(context[:opts], %{vhost: context[:vhost]})
    set_policy(context[:vhost], context[:key], context[:pattern], @value)
    @command.run([], vhost_opts)
    |> assert_policy_list(context)
  end

  test "run: an unreachable node throws a badrpc" do
    target = :jake@thedog
    :net_kernel.connect_node(target)
    opts = %{node: target, vhost: @vhost, timeout: :infinity}

    assert @command.run([], opts) == {:badrpc, :nodedown}
  end

  @tag key: @key, pattern: @pattern, value: @value, vhost: @root
  test "run: a well-formed command with no vhost runs against the default one", context do

    set_policy("/", context[:key], context[:pattern], @value)
    on_exit(fn ->
      clear_policy("/", context[:key])
    end)

    @command.run([], context[:opts])
    |> assert_policy_list(context)
  end

  @tag key: @key, pattern: @pattern, value: @value, vhost: @vhost
  test "run: providing a timeout of 0 returns a badrpc", context do
    set_policy(context[:vhost], context[:key], context[:pattern], @value)
    assert @command.run([], Map.put(context[:opts], :timeout, 0)) == {:badrpc, :timeout}
  end

  @tag key: @key, pattern: @pattern, value: @value, vhost: "bad-vhost"
  test "run: providing a non-existent vhost returns an error", context do
    vhost_opts = Map.merge(context[:opts], %{vhost: context[:vhost]})

    assert @command.run(
      [],
      vhost_opts
    ) == {:error, {:no_such_vhost, context[:vhost]}}
  end

  test "merge_defaults: default vhost is '/'" do
    assert @command.merge_defaults([], %{}) == {[], %{vhost: "/"}}
    assert @command.merge_defaults([], %{vhost: "non_default"}) == {[], %{vhost: "non_default"}}
  end

  @tag vhost: @vhost
  test "run: when multiple policies exist in the vhost, returns them all", context do
    policies = [
      %{vhost: @vhost, name: "some-policy", pattern: "foo", definition: "{\"federation-upstream-set\":\"all\"}", 'apply-to': "all", priority: 0},
      %{vhost: @vhost, name: "other-policy", pattern: "bar", definition: "{\"ha-mode\":\"all\"}", 'apply-to': "all", priority: 0}
    ]
    policies
    |> Enum.map(
        fn(%{name: name, pattern: pattern, definition: value}) ->
          set_policy(context[:vhost], name, pattern, value)
          on_exit(fn ->
            clear_policy(context[:vhost], name)
          end)
        end)

    pols = for policy <- @command.run([], context[:opts]), do: Map.new(policy)

    assert MapSet.new(pols) == MapSet.new(policies)
  end

  @tag key: @key, pattern: @pattern, value: @value, vhost: @vhost
  test "banner", context do
    vhost_opts = Map.merge(context[:opts], %{vhost: context[:vhost]})

    assert @command.banner([], vhost_opts)
      =~ ~r/Listing policies for vhost \"#{context[:vhost]}\" \.\.\./
  end

  # Checks each element of the first policy against the expected context values
  defp assert_policy_list(policies, context) do
    [policy] = policies
    assert MapSet.new(policy) == MapSet.new([name: context[:key],
                                             pattern: context[:pattern],
                                             definition: context[:value],
                                             vhost: context[:vhost],
                                             priority: context[:opts][:priority],
                                             "apply-to": context[:opts][:apply_to]])
  end
end
