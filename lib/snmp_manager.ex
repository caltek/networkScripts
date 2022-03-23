defmodule SNMPManager do
  @behaviour :snmpm_user

  @user_id "default_user"
  @agent 'default_agent'
  @mib_dir "mibs"
  require Logger

  def init() do
    register_user()
    register_agent()
    load_mibs()
  end

  def register_user(community_name \\ "d1b!knew") do
    :snmpm.register_user(@user_id, __MODULE__, :undefined, [
      {:community, community_name},
      {:version, :v2},
      {:sec_model, :v2c},
      {:sec_name, "initial"},
      {:timeout, :infinity},
      {:max_message_size, 484},
      {:sec_level, :noAuthNoPriv}
    ])
  end

  def register_agent(ip_addr \\ "10.44.99.9") do
    net_ip = ip_addr |> String.split(".") |> Enum.map(&String.to_integer/1)

    :snmpm.register_agent(@user_id, @agent, [
      {:address, net_ip},
      {:engine_id, 'default'},
      {:tdomain, :transportDomainUdpIpv4}
    ])
  end

  def load_mibs() do
    "#{@mib_dir}/mibs.bin"
    |> :binary.bin_to_list()
    |> :snmpm.load_mib()
  end

  def handle_agent(_domain, _address, _type, _snmpInfo, _userData) do
  end

  def handle_error(_reqId, _reason, _userData) do
  end

  def handle_pdu(_targetName, _reqId, snmpResponse, _userData) do
    IO.puts("GETTING PDU INFO")
    IO.inspect(snmpResponse)
  end

  def handle_report(_targetName, _snmpReport, _userData) do
  end

  def handle_inform(_targetName, _snmpInform, _userData) do
  end

  def handle_trap(_targetName, snmpTrapInfo, _userData) do
    IO.puts("GETTING TRAP INFO")
    IO.inspect(snmpTrapInfo)
  end

  def get_some_serials(oids \\ [[1, 3, 6, 1, 2, 1, 1, 1, 0]]) do
    :snmpm.sync_get2(@user_id, @agent, oids)
  end
end
