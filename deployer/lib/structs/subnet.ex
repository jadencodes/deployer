defmodule Deployer.Subnet do
	@moduledoc """
	Subnet is a module to hold the structure of a subnet. It also handles interaction with the use.
	"""

	defstruct [:id, :cidr, :state, :owner, :az, :availableIps]
	
	import SweetXml
	alias Deployer.Helpers
	require Logger

	@schema [
			result: [
				~x"//subnetSet"l,
				id: ~x"./item/subnetId/text()"s,
				cidr: ~x"./item/cidrBlock/text()"s,
				state: ~x"./item/state/text()"s,
				owner: ~x"./item/ownerId/text()"s,
				az: ~x"./item/availabilityZoneId/text()"s,
				availableIps: ~x"./item/availableIpAddressCount/text()"s
			]
		]

	@choice_question "Please select which subnet:\n"

	@doc """
	Returns list of `Subnet` structs from xml formatted original

	## Parameters
		* data - XML string of subnet object
	"""
	def map(data) do
		SweetXml.xmap(data, @schema)
		|> Map.get(:result)
		|> Enum.map(fn subnet ->
			struct(Deployer.Subnet, subnet)
		end)
	end

	@doc """
	Returns user picked subnet. Will create subnet if necassary

	## Parameters
		* subnets - List of subnet structs
	"""
	def get_user_choice(subnets \\ []) do
		choices = Helpers.map_choices(subnets)

		display = Enum.reduce(choices, @choice_question, fn {sn, idx}, acc ->
			acc <> "#{idx}. #{sn.id} (#{sn.cidr}) - #{sn.az} (#{sn.availableIps})\n"
		end)

		# show user their options
		IO.puts display

		# wait for their choice
		choice = IO.gets "Select> "
		choice = String.trim(choice) |> Integer.parse()

		user_select(choice, choices, subnets)
	end

	@doc """
	Returns selected subnets group struct based on users choice

	## Parameters
		* choice - Tuple choice from integer check
		* choices - Mapped choices to user choice
		* subnets - All existing subnets
	"""
	def user_select({pick, ""}, choices, _) when pick < length(choices) do
		# extract SN from chocies by pick id
		{picked_sn, _} = List.keyfind(choices, pick, 1)
		IO.puts "You selected subnet: #{picked_sn.id} (#{picked_sn.cidr}) - #{picked_sn.az} (#{picked_sn.availableIps})\n"
		picked_sn
	end

	# catch bad choices
	def user_select(bad_choice, _choices, subnets) do
		IO.puts "Bad choice: #{inspect(bad_choice)}, please choose again.\n"
		get_user_choice(subnets)
	end
end