defmodule ListBindingsCommandTest do
  use ExUnit.Case, async: false
  import TestHelper

  @command ListBindingsCommand
  @vhost "test1"
  @user "guest"
  @root   "/"
  @default_timeout :infinity

  setup_all do
    :net_kernel.start([:rabbitmqctl, :shortnames])
    :net_kernel.connect_node(get_rabbit_hostname)

    on_exit([], fn ->
      :erlang.disconnect_node(get_rabbit_hostname)
      :net_kernel.stop()
    end)

    :ok
  end

  setup context do
    add_vhost @vhost
    set_permissions @user, @vhost, [".*", ".*", ".*"]
    on_exit(fn ->
      delete_vhost @vhost
    end)
    {
      :ok,
      opts: %{
        node: get_rabbit_hostname,
        timeout: context[:test_timeout] || @default_timeout,
        vhost: @vhost
      }
    }
  end

  test "merge_defaults: adds all keys if no keys specificed", context do
    default_keys = ~w(source_name source_kind destination_name destination_kind routing_key arguments)
    declare_queue("test_queue", @vhost)
    :timer.sleep(100)
    
    {keys, _} = @command.merge_defaults([], context[:opts])
    assert default_keys == keys 
  end

  test "validate: returns bad_info_key on a single bad arg", context do
    assert @command.validate(["quack"], context[:opts]) ==
      {:validation_failure, {:bad_info_key, [:quack]}}
  end

  test "validate: returns multiple bad args return a list of bad info key values", context do
    assert @command.validate(["quack", "oink"], context[:opts]) ==
      {:validation_failure, {:bad_info_key, [:quack, :oink]}}
  end

  test "validate: return bad_info_key on mix of good and bad args", context do
    assert @command.validate(["quack", "source_name"], context[:opts]) ==
      {:validation_failure, {:bad_info_key, [:quack]}}
    assert @command.validate(["source_name", "oink"], context[:opts]) ==
      {:validation_failure, {:bad_info_key, [:oink]}}
    assert @command.validate(["source_kind", "oink", "source_name"], context[:opts]) ==
      {:validation_failure, {:bad_info_key, [:oink]}}
  end

  @tag test_timeout: 0
  test "run: zero timeout causes command to return badrpc", context do
    assert run_command_to_list(@command, [["source_name"], context[:opts]]) ==
      [{:badrpc, {:timeout, 0.0}}]
  end

  test "run: no bindings for no queues", context do
    [] = run_command_to_list(@command, [["source_name"], context[:opts]])
  end

  test "run: can filter info keys", context do
    wanted_keys = ~w(source_name destination_name routing_key)
    declare_queue("test_queue", @vhost)
    assert run_command_to_list(@command, [wanted_keys, context[:opts]]) ==
            [[source_name: "", destination_name: "test_queue", routing_key: "test_queue"]]
  end

  test "banner" do
    assert String.starts_with?(@command.banner([], %{vhost: "some_vhost"}), "Listing bindings")
  end
end
