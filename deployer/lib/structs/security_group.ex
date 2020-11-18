defmodule Deployer.SecurityGroup do
	@moduledoc """
	SecurityGroup is a module to hold the structure of a security group. It also handles interaction with the use.

	It is capable of adding ingress rules on demand for a provided security group.
	"""

	defstruct [:id, :name, :description, :vpc_id, :permissions]

	import SweetXml
	alias ExAws.EC2
	alias Deployer.Helpers
	require Logger

	@schema [
			result: [
			~x"//securityGroupInfo/item"l,
			id: ~x"./groupId/text()"s,
			name: ~x"./groupName/text()"s,
			description: ~x"./groupDescription/text()"s,
			vpc_id: ~x"./vpcId/text()"s,
			permissions: [
					~x".//ipPermissions"l,
					protocol: ~x"./item/ipProtocol/text()"s
			]
		]
	]
	
	@choice_question "Please select which security group:\n"

	@default_ingress_rules [
		[ip_protocol: "tcp", from_port: 80, to_port: 80, ip_ranges: [cidr_ip: "0.0.0.0/0"]]
	]

	@doc """
	Returns list of `SecurityGroup` structs from xml formatted original

	## Parameters
		* data - XML string of security groups object
	"""
	def map(data) do
		SweetXml.xmap(data, @schema)
		|> Map.get(:result)
		|> Enum.map(fn sg ->
			struct(Deployer.SecurityGroup, sg)
		end)
	end

	@doc """
	Returns user picked security group id. Will create security group if necassary

	## Parameters
		* security_groups - List of security group structs
	"""
	def get_user_choice(security_groups \\ []) do
		choices = Helpers.map_choices(security_groups)
		display = Enum.reduce(choices, @choice_question, fn {sg, idx}, acc ->
			acc <> "#{idx}. #{sg.name} - #{sg.description}\n"
		end)

		# show user their options
		IO.puts display

		# wait for their choice
		choice = IO.gets "Select> "
		choice = String.trim(choice) |> Integer.parse()

		user_select(choice, choices, security_groups)
	end

	@doc """
	Loads `security_group` with all required rules.
	Intended to be idempotent and not error if rules already exist

	## Parameters
		* security_group - `Deployer.SecurityGroup` to add rules to

	Returns `:ok` if no errors occured. Otherwise `{:error, ERROR}`
	"""
	def add_required_rules(%Deployer.SecurityGroup{} = security_group) do
		perms = [get_personal_ip_rule() | @default_ingress_rules]

		case EC2.authorize_security_group_ingress([group_id: security_group.id, ip_permissions: perms]) |> ExAws.request() do
			{:ok, %{status_code: 200}} -> IO.puts "Successfully generated ingress rules"
			{:error, {:http_error, 400, %{body: err}}} ->
				if err =~ "Duplicate" do
					IO.puts "Ingress rule(s) already exist, skipping"
				else
					IO.puts "Error while attempting to add security group rules:\n#{inspect(err)}"
					{:error, err}
				end
			err -> IO.puts "Error while attempting to add security group rules:\n#{inspect(err)}"
				{:error, err}
		end
	end

	@doc """
	Returns selected security group struct based on users choice

	## Parameters
		* choice - Tuple choice from integer check
		* choices - Mapped choices to user choice
		* security_groups - All existing security groups
	"""
	def user_select({pick, ""}, choices, _) when pick < length(choices) do
		# extract SG from chocies by pick id
		{picked_sg, _} = List.keyfind(choices, pick, 1)
		IO.puts "You selected security group: #{picked_sg.name} (#{picked_sg.id}) - #{picked_sg.description}\n"
		picked_sg
	end

	# catch bad choices
	def user_select(bad_choice, _choices, security_groups) do
		IO.puts "Bad choice: #{inspect(bad_choice)}, please choose again.\n"
		get_user_choice(security_groups)
	end

	defp get_personal_ip_rule() do
		ip = Helpers.get_public_ip()
		[ip_protocol: "tcp", from_port: 22, to_port: 22, ip_ranges: [cidr_ip: "#{ip}/32"]]
	end
end