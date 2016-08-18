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


defmodule RabbitMQ.CLI.Plugins.Commands.ListCommand do

  import RabbitCommon.Records

  alias RabbitMQ.CLI.Ctl.Helpers, as: Helpers

  alias RabbitMQ.CLI.Plugins.Helpers, as: PluginHelpers

  @behaviour RabbitMQ.CLI.CommandBehaviour

  def merge_defaults([], opts), do: merge_defaults([".*"], opts)
  def merge_defaults(args, opts), do: {args, Map.merge(default_opts, opts)}

  def switches(), do: [verbose: :boolean,
                       minimal: :boolean,
                       enabled: :boolean,
                       implicitly_enabled: :boolean,
                       rabbitmq_home: :string,
                       enabled_plugins_file: :string,
                       plugins_dir: :string]
  def aliases(), do: [v: :verbose, m: :minimal,
                      'E': :enabled, e: :implicitly_enabled]

  def validate(args, _) when length(args) > 1 do
    {:validation_failure, :too_many_args}
  end

  def validate(_, %{verbose: true, minimal: true}) do
    {:validation_failure, {:bad_argument, "Cannot set both verbose and minimal"}}
  end

  def validate(_, opts) do
    :ok
    |> validate_step(fn() -> Helpers.require_rabbit(opts) end)
    |> validate_step(fn() -> PluginHelpers.enabled_plugins_file(opts) end)
    |> validate_step(fn() -> PluginHelpers.plugins_dir(opts) end)
  end

  def validate_step(:ok, step) do
    case step.() do
      {:error, err} -> {:validation_failure, err};
      _             -> :ok
    end
  end
  def validate_step({:validation_failure, err}, _) do
    {:validation_failure, err}
  end

  def usage, do: "list [pattern] [--verbose] [--minimal] [--enabled] [--implicitly-enabled]"

  def banner([pattern], _), do: "Listing plugins with pattern \"#{pattern}\" ..."

  def flags, do: Keyword.keys(switches())

  def run([pattern], %{node: node_name} = opts) do
    %{verbose: verbose, minimal: minimal,
      enabled: only_enabled,
      implicitly_enabled: all_enabled} = opts

    all     = PluginHelpers.list(opts)
    enabled = PluginHelpers.read_enabled(opts)

    case MapSet.difference(MapSet.new(enabled), MapSet.new(plugin_names(all))) do
        %MapSet{} -> :ok;
        missing   -> IO.puts("WARNING - plugins currently enabled but missing: #{missing}~n~n")
    end
    implicit           = :rabbit_plugins.dependencies(false, enabled, all)
    enabled_implicitly = implicit -- enabled

    {status, running} =
        case :rabbit_misc.rpc_call(node_name, :rabbit_plugins, :active, []) do
            {:badrpc, _} -> {:node_down, []};
            active       -> {:running, active}
        end

    {:ok, re} = Regex.compile(pattern)

    format = case {verbose, minimal} do
      {true, false}  -> :verbose;
      {false, true}  -> :minimal;
      {false, false} -> :normal
    end

    plugins = Enum.filter(all,
      fn(plugin) ->
        name = plugin_name(plugin)

        Regex.match?(re, to_string(name)) and
        cond do
          only_enabled -> Enum.member?(enabled, name);
          all_enabled  -> Enum.member?(enabled ++ enabled_implicitly, name);
          true         -> true
        end
      end)

    %{status: status,
      plugins: format_plugins(plugins, format, enabled, enabled_implicitly, running)}
  end

  defp format_plugins(plugins, format, enabled, enabled_implicitly, running) do
    plugins
    |> sort_plugins
    |> Enum.map(fn(plugin) ->
        format_plugin(plugin, format, enabled, enabled_implicitly, running)
       end)
  end

  defp sort_plugins(plugins) do
    Enum.sort_by(plugins, &plugin_name/1)
  end

  defp format_plugin(plugin, :minimal, _, _, _) do
    plugin_name(plugin)
  end
  defp format_plugin(plugin, :normal, enabled, enabled_implicitly, running) do
    plugin(name: name, version: version) = plugin
    enabled_mode = case {Enum.member?(enabled, name), Enum.member?(enabled_implicitly, name)} do
      {true, false}  -> :enabled;
      {false, true}  -> :implicit;
      {false, false} -> :not_enabled
    end
    %{name: name,
      version: version,
      enabled: enabled_mode,
      running: Enum.member?(running, name)}
  end
  defp format_plugin(plugin, :verbose, enabled, enabled_implicitly, running) do
    normal = format_plugin(plugin, :normal, enabled, enabled_implicitly, running)
    plugin(dependencies: dependencies, description: description) = plugin
    Map.merge(normal, %{dependencies: dependencies, description: description})
  end

  defp plugin_names(plugins) do
    for plugin <- plugins, do: plugin_name(plugin)
  end

  defp plugin_name(plugin) do
    plugin(name: name) = plugin
    name
  end

  defp default_opts() do
    %{minimal: false, verbose: false,
      enabled: false, implicitly_enabled: false}
  end

end
