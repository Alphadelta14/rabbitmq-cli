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
## The Initial Developer of the Original Code is Pivotal Software, Inc.
## Copyright (c) 2016-2020 VMware, Inc. or its affiliates.  All rights reserved.

defmodule RabbitMQ.CLI.Core.Distribution do
  alias RabbitMQ.CLI.Core.{ANSI, Config, Helpers}

  #
  # API
  #

  def start() do
    start(%{})
  end

  def start(options) do
    node_name_type = Config.get_option(:longnames, options)
    result = start(node_name_type, 10, :undefined)
    ensure_cookie(options)
    result
  end

  def stop, do: Node.stop()

  def start_as(node_name, options) do
    node_name_type = Config.get_option(:longnames, options)
    result = start_with_epmd(node_name, node_name_type)
    ensure_cookie(options)
    result
  end

  ## Optimization. We try to start EPMD only if distribution fails
  def start_with_epmd(node_name, node_name_type) do
    case Node.start(node_name, node_name_type) do
      {:ok, _} = ok ->
        ok

      {:error, {:already_started, _}} = started ->
        started

      {:error, {{:already_started, _}, _}} = started ->
        started

      ## EPMD can be stopped. Retry with EPMD
      {:error, _} ->
        :rabbit_nodes_common.ensure_epmd()
        Node.start(node_name, node_name_type)
    end
  end

  def per_node_timeout(:infinity, _) do
    :infinity
  end
  def per_node_timeout(timeout, node_count) do
    Kernel.trunc(timeout / node_count)
  end

  #
  # Implementation
  #

  def ensure_cookie(options) do
    case Config.get_option(:erlang_cookie, options) do
      nil ->
        :ok

      cookie ->
        Node.set_cookie(cookie)
        maybe_warn_about_deprecated_rabbitmq_erlang_cookie_env_variable(options)
        :ok
    end
  end

  defp start(_opt, 0, last_err) do
    {:error, last_err}
  end

  defp start(node_name_type, attempts, _last_err) do
    candidate = generate_cli_node_name(node_name_type)

    case start_with_epmd(candidate, node_name_type) do
      {:ok, _} ->
        :ok

      {:error, {:already_started, pid}} ->
        {:ok, pid}

      {:error, {{:already_started, pid}, _}} ->
        {:ok, pid}

      {:error, reason} ->
        start(node_name_type, attempts - 1, reason)
    end
  end

  defp generate_cli_node_name(node_name_type) do
    case Helpers.get_rabbit_hostname(node_name_type) do
      {:error, _} = err -> throw(err)
      rmq_hostname      -> String.to_atom("rabbitmqcli-#{:os.getpid()}-#{rmq_hostname}")
    end
  end

  defp maybe_warn_about_deprecated_rabbitmq_erlang_cookie_env_variable(options) do
      case System.get_env("RABBITMQ_ERLANG_COOKIE") do
        nil -> :ok
        _   ->
          case Config.output_less?(options) do
            true  -> :ok
            false ->
              warning = ANSI.bright_red("RABBITMQ_ERLANG_COOKIE env variable support is deprecated and will be REMOVED in a future version. ") <>
                        ANSI.yellow("Use the $HOME/.erlang.cookie file or the --erlang-cookie switch instead.")

              IO.puts(warning)
          end
      end
  end
end
