defmodule Deployer.VPC do
	@moduledoc """
	VPC is a module to hold the structure of a vpc.

	It's main purpose is to convert xml from the requests into a stucture.
	"""

	defstruct [:id, :cidr, :state, :owner, :tags]
	
	import SweetXml
	require Logger

	@schema [
			result: [
				~x"//vpcSet"l,
				id: ~x"./item/vpcId/text()"s,
				cidr: ~x"./item/cidrBlock/text()"s,
				state: ~x"./item/state/text()"s,
				owner: ~x"./item/ownerId/text()"s,
				tags: [
						~x".//tagSet"l,
						key: ~x"./item/key/text()"s,
						value: ~x"./item/value/text()"s
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
			struct(Deployer.VPC, vpc)
		end)
	end
end