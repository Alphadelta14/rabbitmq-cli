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


defmodule SetUserTagsCommandTest do
  use ExUnit.Case, async: false
  import TestHelper

  @user     "user1"
  @password "password"

  setup_all do
    RabbitMQCtl.start_distribution()
    :net_kernel.connect_node(get_rabbit_hostname)
    add_user @user, @password

    on_exit([], fn ->
      delete_user(@user)
      :erlang.disconnect_node(get_rabbit_hostname)
      :net_kernel.stop()
    end)

    :ok
  end

  setup context do
    context[:user] # silences warnings
    on_exit([], fn -> set_user_tags(context[:user], []) end)

    {:ok, opts: %{node: get_rabbit_hostname}}
  end

  test "validate: on an incorrect number of arguments, return an arg count error" do
    assert SetUserTagsCommand.validate([], %{}) == {:validation_failure, :not_enough_args}
  end

  test "run: An invalid rabbitmq node throws a badrpc" do
    target = :jake@thedog
    :net_kernel.connect_node(target)
    opts = %{node: target}

    assert SetUserTagsCommand.run([@user, "imperator"], opts) == {:badrpc, :nodedown}
  end

  @tag user: @user, tags: ["imperator"]
  test "run: on a single optional argument, add a flag to the user", context  do
    SetUserTagsCommand.run(
      [context[:user] | context[:tags]],
      context[:opts]
    )

    result = Enum.find(
      list_users,
      fn(record) -> record[:user] == context[:user] end
    )

    assert result[:tags] == context[:tags]
  end

  @tag user: "interloper", tags: ["imperator"]
  test "run: on an invalid user, get a no such user error", context do
    assert SetUserTagsCommand.run(
      [context[:user] | context[:tags]],
      context[:opts]
    ) == {:error, {:no_such_user, context[:user]}}
  end

  @tag user: @user, tags: ["imperator", "generalissimo"]
  test "run: on multiple optional arguments, add all flags to the user", context  do
    SetUserTagsCommand.run(
      [context[:user] | context[:tags]],
      context[:opts]
    )

    result = Enum.find(
      list_users,
      fn(record) -> record[:user] == context[:user] end
    )

    assert result[:tags] == context[:tags]
  end

  @tag user: @user, tags: ["imperator"]
  test "run: with no optional arguments, clear user tags", context  do

    set_user_tags(context[:user], context[:tags])

    SetUserTagsCommand.run([context[:user]], context[:opts])

    result = Enum.find(
      list_users,
      fn(record) -> record[:user] == context[:user] end
    )

    assert result[:tags] == []
  end

  @tag user: @user, tags: ["imperator"]
  test "run: identical calls are idempotent", context  do

    set_user_tags(context[:user], context[:tags])

    assert SetUserTagsCommand.run(
      [context[:user] | context[:tags]],
      context[:opts]
    ) == :ok

    result = Enum.find(
      list_users,
      fn(record) -> record[:user] == context[:user] end
    )

    assert result[:tags] == context[:tags]
  end

  @tag user: @user, old_tags: ["imperator"], new_tags: ["generalissimo"]
  test "run: if different tags exist, overwrite them", context  do

    set_user_tags(context[:user], context[:old_tags])

    assert SetUserTagsCommand.run(
      [context[:user] | context[:new_tags]],
      context[:opts]
    ) == :ok

    result = Enum.find(
      list_users,
      fn(record) -> record[:user] == context[:user] end
    )

    assert result[:tags] == context[:new_tags]
  end

  @tag user: @user, tags: ["imperator"]
  test "banner", context  do
    assert SetUserTagsCommand.banner(
        [context[:user] | context[:tags]],
        context[:opts]
      )
      =~ ~r/Setting tags for user \"#{context[:user]}\" to \[#{context[:tags]}\] \.\.\./
  end

end
