defmodule Deployer.Instances do
	@moduledoc """
	Main module for interacting with AWS.

	These interactions include: preflight checks, launching instances, security group interaction, subnet interaction, and more.
	"""
	
	alias ExAws.EC2
	alias Deployer.{SecurityGroup, VPC, Subnet, Instance, Manifest}
	
	require Logger

	@retry_instance_state_time 1000

	@doc """
	Launch ec2 instance after getting user input.

	## Parameters
		* manifest - Manifest to use to deploy
		* vpc_id - Id of vpc to launch in
		* key_pair - EC2 key pair to use (must already be loaded in aws)
	"""
	@spec launch(Manifest, String.t(), String.t()) :: {:ok, Deployer.Instance} | :error
	def launch(manifest, vpc_id, key_pair) do
		case preflight(vpc_id) do
			{:ok, subnet, security_group} -> IO.puts "Preflight successful, starting instance launch..."
				run_instance(manifest, subnet, security_group, key_pair)
			{:error, _err} -> IO.puts "Failed preflight check"
				:error
		end
	end

	@doc """
	Run preflight to get user input for desired subnet and security group.

	## Parameters
		* vpc_id - Id of vpc to launch in
	"""
	@spec preflight(String.t()) :: {:ok, Subnet, SecurityGroup} | {:error, any()}
	def preflight(vpc_id) do
		IO.puts "Starting preflight check..."

		with {:ok, _vpc} <- get_vpc(vpc_id),
			{:ok, subnet} <- get_subnet(vpc_id),
			{:ok, security_group} <- get_security_group(vpc_id)
		do
			{:ok, subnet, security_group}
		else
			err -> Logger.error "Error in preflight:\n#{inspect(err)}"
				{:error, err}
		end
	end

	@doc """
	Run instance defined in manifest.

	## Parameters
		* manifest - Manifest to use to deploy
		* subnet - Subnet to launch in
		* security_group - Security group to add to instance
		* key_pair - EC2 key pair to use
	"""
	@spec run_instance(Manifest, Subnet, SecurityGroup, String.t()) :: {:ok, Instance} | {:error, any()}
	def run_instance(manifest, subnet, security_group, key_pair) do
		IO.puts "Starting instance. AMI: #{manifest.ami}, Instance Type: #{manifest.instance_type}, Key Pair: #{key_pair}, Subnet: #{subnet.id}, Security Group: #{security_group.id}"
		case EC2.run_instances(manifest.ami, 1, 1,
				instance_type: manifest.instance_type,
				key_name: key_pair,
				network_interfaces: [device_index: 0, delete_on_termination: true, subnet_id: subnet.id, associate_public_ip_address: true, security_group_id: [security_group.id]]
			) |> ExAws.request() do
			{:ok, %{status_code: 200, body: xml}} ->
				# struct maps lists, not single instances
				[instance] = Instance.map(xml)
				IO.puts "Waiting for instance #{instance.id} to be ready..."

				wait_until_running(instance)
				[instance] = get_instance_status(instance)
				IO.puts "\nInstance #{instance.id} ready, public ip: #{instance.public_ip}"

				{:ok, instance}
			err -> Logger.error "Failed to run instance, error:\n#{inspect(err)}"
				{:error, err}
		end
	end

	@doc """
	Bootstrap instance by installing dependencies and desired files in manifest.

	## Parameters
		* manifest - Manifest to use to deploy
		* instance - Instance that has already been deployed
		* private_key_path - Path to private key file to use (private key of key_pair)
		* known_hosts_path - Path to known hosts file
	"""
	@spec bootstrap(Manifest, Instance, String.t(), String.t()) :: :ok | :error
	def bootstrap(manifest, instance, private_key_path, known_hosts_path) do
		deps = Enum.join(manifest.dependencies, " ")
		IO.puts "Bootstrapping server with dependencies: #{deps}"

		# TODO: make this command configurable so other package managers can be used
		cmd = "sudo apt update 1> /dev/null 2>&1 && sudo apt install -y #{deps} 1> /dev/null"

		with {:ok, conn} <- Instance.connect_ssh(to_charlist(instance.public_ip), to_charlist(manifest.username), private_key_path, known_hosts_path, 10),
			:ok <- Instance.run_command(conn, cmd),
			:ok <- (Instance.upload_files(instance.public_ip, manifest.username, private_key_path, known_hosts_path, manifest.copy_files) && IO.puts "Successfully uploaded files")
		do
			IO.puts "Successfully bootstrapped instance #{instance.id}"
			:ok
		else
			err -> IO.puts "Failed to execute command: #{cmd}. Error:\n#{inspect(err)}"
			:error
		end
	end

	@doc """
	Start application that has been uploaded.

	## Parameters
		* manifest - Manifest to use to deploy
		* instance - Instance that has already been deployed
		* private_key_path - Path to private key file to use (private key of key_pair)
		* known_hosts_path - Path to known hosts file
	"""
	@spec start_app(Manifest, Instance, String.t(), String.t()) :: :ok | :error
	def start_app(manifest, instance, private_key_path, known_hosts_path) do
		IO.puts "Starting app #{manifest.name}..."
		with {:ok, conn} <- Instance.connect_ssh(to_charlist(instance.public_ip), to_charlist(manifest.username), private_key_path, known_hosts_path, 10),
			:ok <- Instance.run_commands(conn, manifest.start_cmds)
		do
			IO.puts "Successfully started app: #{manifest.name}"
			:ok
		else	
			err -> IO.puts "Error starting app:\n#{inspect(err)}"
				:error
		end
	end

	@doc """
	Checks if given vpc exists, Deployer doesn't current support creating vpcs

	## Parameters
		* vpc_id - VPC id already generated ahead of time
	"""
	@spec get_vpc(String.t()) :: {:ok, map} | {:error, any()}
	def get_vpc(vpc_id) do
		case EC2.describe_vpcs() |> ExAws.request() do
			{:ok, %{status_code: 200, body: xml}} ->
				# IO.inspect xml
				case Enum.find(VPC.map(xml), fn vpc -> vpc.id == vpc_id end) do
					nil -> {:error, "VPC not found"}
					good -> {:ok, good}
				end
			err -> Logger.error "Failed to describe vpc, error:\n#{inspect(err)}"
				{:error, err}
		end
	end

	@doc """
	Get subnet selection from user by querying EC2 and asking for choice.
	
	## Parameters
		* vpc_id - VPC id already generated ahead of time
	"""
	@spec get_subnet(String.t()) :: {:ok, Subnet} | {:error, any()}
	def get_subnet(vpc_id) do
		IO.puts "Setting up subnet..."

		case EC2.describe_subnets(filters: ["vpc-id": [vpc_id]]) |> ExAws.request() do
			{:ok, %{status_code: 200, body: xml}} ->
				sns = Subnet.map(xml)
				# will continue asking them until valid
				choice = Subnet.get_user_choice(sns)

				{:ok, choice}
			err -> Logger.error "Failed to describe subnets:\n#{inspect(err)}"
		end
	end

	@doc """
	Get security group selection from user by querying EC2 and asking for choice.
	
	## Parameters
		* vpc_id - VPC id already generated ahead of time
	"""
	@spec get_security_group(String.t()) :: {:ok, SecurityGroup} | {:error, any()}
	def get_security_group(vpc_id) do
		IO.puts "Setting up security group..."

		case EC2.describe_security_groups(filters: ["vpc-id": [vpc_id]]) |> ExAws.request() do
			{:ok, %{status_code: 200, body: xml}} ->
				sgs = SecurityGroup.map(xml)
				choice = SecurityGroup.get_user_choice(sgs)

				# returns :ok or {:error, err}
				case SecurityGroup.add_required_rules(choice) do
					:ok -> {:ok, choice}
					err -> err
				end
			err -> Logger.error "Failed to describe security groups:\n#{inspect(err)}"
		end
	end

	@doc """
	Get instance status.
	
	## Parameters
		* instance - Instance from aws
	"""
	@spec get_instance_status(Instance) :: Instance | :error
	def get_instance_status(instance) do
		case EC2.describe_instances(filters: ["instance-id": instance.id]) |> ExAws.request() do
			{:ok, %{status_code: 200, body: xml}} ->
				Instance.map(xml)
				
			err -> Logger.error "Failed to describe instances:\n#{inspect(err)}"
				:error
		end
	end

	@doc """
	Wait for instance to enter the running state.

	## Parameters
		* instance - Instance from aws
	"""
	@spec wait_until_running(Instance) :: Instance
	def wait_until_running(instance) do
		case get_instance_status(instance) do
			[%{state: "running"}] = instance -> instance
			[instance] -> :timer.sleep(@retry_instance_state_time)
				IO.write "."
				wait_until_running(instance)
		end
	end
end