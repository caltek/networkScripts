defmodule NetworkScripts do
  @moduledoc """
  Documentation for `NetworkScripts`.
  """
  @filename "noah_ips.xlsx"
  def parse_file() do
    Xlsxir.multi_extract(@filename)
    |> then(fn [head | tail] ->
      %{
        bw_mapper: head,
        sites: tail
      }
    end)
    |> gen_bw_mapper()
    |> translate_ip_bw_info()
    |> translat_to_command()
  end

  defp gen_bw_mapper(%{bw_mapper: {:ok, sheet_id}} = shw) do
    Xlsxir.get_list(sheet_id)
    |> Enum.reduce(%{}, fn [old, new], acc ->
      Map.put(acc, old, new)
    end)
    |> then(&%{shw | bw_mapper: &1})
  end

  defp translat_to_command(bw_info) do
    bw_info
    |> Enum.each(&build_upgrade_command/1)
  end

  defp build_upgrade_command(%{host: host, info: bw_list}) do
    bw_list
    |> Enum.filter(&(not is_nil(&1.new_bw)))
    |> Enum.each(fn %{new_bw: new_bw, queue: queue_no, ip_addr: addr} ->
      File.write!(
        "router_#{host}_debug.log",
        ~s(IP#{addr}\nset traffic-control advanced-queue leaf queue #{queue_no} bandwidth #{new_bw}\n),
        [:append]
      )

      File.write!(
        "router_#{host}.log",
        ~s(set traffic-control advanced-queue leaf queue #{queue_no} bandwidth #{new_bw}\n),
        [:append]
      )
    end)
  end

  def translate_ip_bw_info(%{sites: sites, bw_mapper: mapper}) do
    IO.inspect(mapper)

    sites
    |> Enum.map(fn {:ok, sheet_id} ->
      Xlsxir.get_list(sheet_id)
      |> then(fn [[host | _host_tail] | user_ips] ->
        host
        |> base_config()
        |> get_match_queues(user_ips, mapper)
        |> List.flatten()
        |> then(&%{host: host, info: &1})
      end)
    end)
  end

  def get_match_queues(config, ips, mapper) do
    ips
    |> Enum.map(&scrap_ip_info(&1, config, mapper))
  end

  def scrap_ip_info([ip_addr | _tail], config, mapper) do
    ~r/advanced-queue filters match (?<que_no>\d+) ip (source|destination) address #{ip_addr}\/32/
    |> Regex.scan(config, capture: :all_but_first)
    |> Enum.map(fn [head | _tail] ->
      ~r/advanced-queue leaf queue #{head} bandwidth (?<bw>\d+)(mbit|kbit|mbps)/
      |> Regex.scan(config, capture: :all_but_first)
      |> List.first()
      |> then(
        &case &1 do
          nil ->
            %{ip_addr: ip_addr, queue: head, old_bw: nil, new_bw: nil}

          [bw, measurment] ->
            format_result(ip_addr, head, bw, measurment, mapper)
        end
      )
    end)
  end

  defp format_result(ip_addr, queue_name, old_bw, measurement, mapper) do
    Map.get(mapper, String.to_integer(old_bw))
    |> case do
      nil ->
        %{ip_addr: ip_addr, queue: queue_name, old_bw: "#{old_bw}#{measurement}", new_bw: nil}

      new_bw ->
        %{
          ip_addr: ip_addr,
          queue: queue_name,
          old_bw: "#{old_bw}#{measurement}",
          new_bw: "#{new_bw}#{measurement}"
        }
    end
  end

  @username 'Adugna'
  @password 'Ad70228329'
  @config_cmd "/opt/vyatta/bin/vyatta-op-cmd-wrapper show configuration commands\n"
  def base_config(host) do
    connect(host)
    |> case do
      {:ok, conn} ->
        conn

      other ->
        IO.inspect(other)
        raise "Unable to form connection"
    end
    |> SSHEx.cmd!(@config_cmd)
  end

  def connect(host) do
    :ssh.connect(String.to_charlist(host), 22, [
      {:user, @username},
      {:password, @password}
    ])
  end
end
