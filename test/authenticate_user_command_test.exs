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


defmodule AuthenticateUserCommandTest do
  use ExUnit.Case, async: false
  import TestHelper

  @command  AuthenticateUserCommand
  @user     "user1"
  @password "password"

  setup_all do
    RabbitMQCtl.start_distribution(%{})
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

  test "validate: invalid number of arguments returns a validation failure" do
    assert @command.validate([], %{}) == {:validation_failure, :not_enough_args}
    assert @command.validate(["user"], %{}) == {:validation_failure, :not_enough_args}
    assert @command.validate(["user", "password", "extra"], %{}) ==
      {:validation_failure, :too_many_args}
  end
  test "validate: correct arguments return :ok" do
    assert @command.validate(["user", "password"], %{}) == :ok
  end

  @tag user: @user, password: @password
  test "run: a valid username and password returns okay", context do
    assert {:ok, _} = @command.run([context[:user], context[:password]], context[:opts])
  end

  test "run: An invalid rabbitmq node throws a badrpc" do
    target = :jake@thedog
    :net_kernel.connect_node(target)
    opts = %{node: target}
    assert @command.run(["user", "password"], opts) == {:badrpc, :nodedown}
  end

  @tag user: @user, password: "treachery"
  test "run: a valid username and invalid password returns refused", context do
    assert {:refused, _, _, _} = @command.run([context[:user], context[:password]], context[:opts])
  end

  @tag user: "interloper", password: @password
  test "run: an invalid username returns refused", context do
    assert {:refused, _, _, _} = @command.run([context[:user], context[:password]], context[:opts])
  end

  @tag user: @user, password: @password
  test "banner", context do
    assert @command.banner([context[:user], context[:password]], context[:opts])
      =~ ~r/Authenticating user/
    assert @command.banner([context[:user], context[:password]], context[:opts])
      =~ ~r/"#{context[:user]}"/    
  end
end
