defmodule Deployer.Instance do
	@moduledoc """
	Instance is a module to hold the structure of a ec2 instance. It also handles interaction with the ec2 instance.

	These interactions include: connecting via ssh, uploading files, and running commands.
	"""
	
	defstruct [:id, :image, :state, :private_ip, :public_ip, :az, :nics, :tags]
	import SweetXml

	@schema [
			result: [
				~x"//instancesSet/item"l,
				id: ~x"./instanceId/text()"s,
				image: ~x"./imageId/text()"s,
				state: ~x"./instanceState/name/text()"s,
				private_ip: ~x"./privateIpAddress/text()"s,
				public_ip: ~x"./ipAddress/text()"s,
				az: ~x"./availabilityZone/text()"s,
				nics:  [
					~x"./networkInterfaceSet/item"l,
					id: ~x"./networkInterfaceId/text()"s,
					private_ip: ~x"./privateIpAddress/text()"s,
					public_ip: ~x"./publicIpAddress/text()"s
				],
				tags: [
						~x"./tagSet/item"l,
						key: ~x"./key/text()"s,
						value: ~x"./value/text()"s
				]
			]
		]

	@doc """
	Returns list of `VPC` structs from xml formatted original

	## Parameters
		* data - XML string of security groups object
	"""
	def map(data) do
		SweetXml.xmap(data, @schema)
		|> Map.get(:result)
		|> Enum.map(fn vpc ->
			struct(Deployer.Instance, vpc)
		end)
	end

	@doc """
	Establish ssh connection to instance.

	## Parameters
		* ip - IP of host to connect to
		* username - User to use for login
		* private_key_file - Path to private key file to use (private key of key_pair)
		* known_hosts_file - Path to known hosts file
		* retries - Number of retries to use on connection
	"""
	@spec connect_ssh(charlist(), charlist(), String.t(), String.t(), pos_integer) :: {:ok, map()} | {:error, any()}
	def connect_ssh(ip, username, private_key_file, known_hosts_file, retries \\ 1)
	def connect_ssh(_, _, _, _, retries) when retries < 1, do: {:error, :out_of_retries}
	def connect_ssh(ip, username, private_key_file, known_hosts_file, retries) do
  		key = File.open!(Path.expand(private_key_file))
  		known_hosts = File.open!(Path.expand(known_hosts_file))

  		cb = SSHClientKeyAPI.with_options(identity: key, known_hosts: known_hosts, silently_accept_hosts: true)

		case SSHEx.connect(ip: ip, user: username, key_cb: cb) do
			{:ok, conn} -> IO.puts "SSH connection established to #{username}@#{ip}"
				{:ok, conn}
			{:error, :econnrefused} -> # retry
				:timer.sleep(1000)
				IO.puts "Failed ssh connection, attempting retry #{retries}"
				connect_ssh(ip, username, private_key_file, known_hosts_file, retries - 1)
			err -> IO.puts "Error while connecting to #{username}@#{ip}:\n#{inspect(err)}"
				{:error, err}
		end
	end

	@doc """
	Run command on established ssh connection.

	## Parameters
		* connection - SSH connection from `connect_ssh`
		* cmd - Command to run on instance
	"""
	@spec run_command(map(), String.t()) :: :ok | {:error, any()}
	def run_command(connection, cmd) do
		IO.puts "Executing command: #{cmd}"
		str = SSHEx.stream(connection, cmd, exec_timeout: :infinity, channel_timeout: 10000)
		Enum.each(str, fn(x) ->
			case x do
				{:stdout, row} -> IO.write row
				{:stderr, row} -> IO.write "Error: #{row}"
				{:status, 0} -> IO.write "\n"
					:ok
				{:status, bad} -> IO.write "\n"
					{:error, bad}
				{:error, reason}  -> {:error, reason}
			end
		end)
	end

	@doc """
	Run multiple commands on established ssh connection

	## Parameters
		* connection - SSH connection from `connect_ssh`
		* commands - List of commands to run
	"""
	@spec run_commands(map(), list(String.t())) :: :ok | {:error, any()}
	def run_commands(_, []), do: :ok
	def run_commands(connection, [cmd | tail]) do
		case run_command(connection, cmd) do
			:ok -> run_commands(connection, tail)
			err -> err
		end
	end

	@doc """
	Upload file to instance.
	
	## Parameters
		* ip - IP of host to connect to
		* username - User to use for login
		* private_key_file - Path to private key file to use (private key of key_pair)
		* known_hosts_file - Path to known hosts file
		* file - Map defining `src` and `dest` of file to upload
	"""
	@spec upload_file(charlist(), charlist(), String.t(), String.t(), map()) :: :ok
	def upload_file(ip, username, private_key_file, known_hosts_file, %{src: source, dest: destination}) do
		key = File.open!(Path.expand(private_key_file))
		known_hosts = File.open!(Path.expand(known_hosts_file))

		cb = SSHClientKeyAPI.with_options(identity: key, known_hosts: known_hosts, silently_accept_hosts: true)

		SFTPClient.connect([host: ip, user: username, connect_timeout: 30000, operation_timeout: :infinity, key_cb: cb], fn conn ->
			IO.puts "Connected over sftp, starting transfer of #{source} -> #{destination}"
			source_stream = File.stream!(Path.expand(source), [], 131_072) #max size after messing around
			target_stream = SFTPClient.stream_file!(conn, destination)

			source_stream
			|> Stream.into(target_stream)
			|> Stream.run()

			IO.puts "Transfer complete #{source} -> #{destination}"
		end)
	end

	@doc """
	Upload multiple files to instance.
	
	## Parameters
		* ip - IP of host to connect to
		* username - User to use for login
		* private_key_file - Path to private key file to use (private key of key_pair)
		* known_hosts_file - Path to known hosts file
		* files - List of files to upload defined by maps with `src` and `dest` of file to upload
	"""
	@spec upload_files(charlist(), charlist(), String.t(), String.t(), list(map())) :: :ok | any()
	def upload_files(_, _, _, _, []), do: :ok
	def upload_files(ip, username, private_key_file, known_hosts_file, [file | tail]) do
		case upload_file(ip, username, private_key_file, known_hosts_file, file) do
			:ok -> upload_files(ip, username, private_key_file, known_hosts_file, tail)
			err -> err
		end
	end
end