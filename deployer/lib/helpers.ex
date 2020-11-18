defmodule Deployer.Helpers do
	def get_public_ip() do
		# :inets.start
		{:ok, {_, _, inet_addr}} = :httpc.request('http://api.ipify.org')
		# :inets.stop
		to_string(inet_addr)
	end

	@doc """
	Returns indexed list of tuples for user to select from.

	## Parameters
		* choices - List of structs

	Returns list such as ```[{%{name: NAME, id: ID, description, DESC}, 0}, {%{name: NAME, id: ID, description, DESC}, 1}]```
	"""
	@spec map_choices(list()) :: list()
	def map_choices(choices) do
		Enum.with_index(choices)
	end
end