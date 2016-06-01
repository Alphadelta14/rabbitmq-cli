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


defmodule ChangePasswordCommandTest do
  use ExUnit.Case, async: false
  import TestHelper

  @command  ChangePasswordCommand
  @user     "user1"
  @password "password"

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
    add_user(@user, @password)
    on_exit(context, fn -> delete_user(@user) end)
    {:ok, opts: %{node: get_rabbit_hostname}}
  end

  test "validate: argument count validation" do
    assert @command.validate(["user", "password"], %{}) == :ok
    assert @command.validate([], %{}) == {:validation_failure, :not_enough_args}
    assert @command.validate(["user"], %{}) == {:validation_failure, :not_enough_args}
    assert @command.validate(["user", "password", "extra"], %{}) ==
      {:validation_failure, :too_many_args}
  end

  @tag user: @user, password: "new_password"
  test "run: a valid username and new password return ok", context do
    assert @command.run([context[:user], context[:password]], context[:opts]) == :ok
    assert {:ok, _} = authenticate_user(context[:user], context[:password])
  end

  test "run: An invalid rabbitmq node throws a badrpc" do
    target = :jake@thedog
    :net_kernel.connect_node(target)
    opts = %{node: target}
    assert @command.run(["user", "password"], opts) == {:badrpc, :nodedown}
  end

  @tag user: @user, password: @password
  test "run: changing password to the same thing is ok", context do
    assert @command.run([context[:user], context[:password]], context[:opts]) == :ok
    assert {:ok, _} = authenticate_user(context[:user], context[:password])
  end

  @tag user: "interloper", password: "new_password"
  test "run: an invalid user returns an error", context do
    assert @command.run([context[:user], context[:password]], context[:opts]) == {:error, {:no_such_user, "interloper"}}
  end

  @tag user: @user, password: @password
  test "banner", context do
    assert @command.banner([context[:user], context[:password]], context[:opts])
      =~ ~r/Changing password for user/
    assert @command.banner([context[:user], context[:password]], context[:opts])
      =~ ~r/"#{context[:user]}"/
  end
end
